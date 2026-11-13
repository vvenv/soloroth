#!/usr/bin/env python3
"""Download (or repair) a large file in parallel 10 MiB ranges and verify it
against an S3/R2 multipart ETag ("<md5 of part md5s>-<parts>").

  tools/macos/mpq-fetch.py <url> <out>

An existing <out> is repaired in place: only parts whose md5 is unknown-good
are fetched again, so a resumed or holed download costs just the bad parts.
Exit 0 when the ETag matches; 1 otherwise.
"""
import concurrent.futures as cf
import hashlib
import os
import subprocess
import sys
import time
import urllib.request

PART = 10 * 1024 * 1024
# R2 answers 403 to Python-urllib's default agent.
UA = {"User-Agent": "curl/8.7.1"}
WORKERS = 12


def head(url):
    req = urllib.request.Request(url, method="HEAD", headers=UA)
    with urllib.request.urlopen(req, timeout=60) as r:
        return int(r.headers["Content-Length"]), r.headers.get("ETag", "").strip('"')


# Through curl: macOS's system Python stalls on long TLS reads from R2.
def get_range(url, start, end):
    last = None
    for attempt in range(8):
        p = subprocess.run(
            ["curl", "-sfL", "--speed-limit", "10000", "--speed-time", "30",
             "-r", "%d-%d" % (start, end), url],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if p.returncode == 0 and len(p.stdout) == end - start + 1:
            return p.stdout
        last = "curl exit %d, %d bytes" % (p.returncode, len(p.stdout))
        time.sleep(2 + attempt * 2)
    raise RuntimeError("range %d-%d: %s" % (start, end, last))


def part_md5(fd, i, size):
    start = i * PART
    n = min(PART, size - start)
    return hashlib.md5(os.pread(fd, n, start)).digest()


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    url, out = sys.argv[1], sys.argv[2]
    size, etag = head(url)
    want_md5, _, nparts = etag.partition("-")
    nparts = int(nparts) if nparts else 0
    if nparts and (nparts - 1) * PART >= size or nparts and nparts * PART < size:
        nparts = 0  # not 10 MiB parts: download whole, verify size only

    fd = os.open(out, os.O_RDWR | os.O_CREAT, 0o644)
    if os.fstat(fd).st_size != size:
        os.ftruncate(fd, size)
    count = (size + PART - 1) // PART

    def fetch(i):
        start = i * PART
        end = min(size, start + PART) - 1
        os.pwrite(fd, get_range(url, start, end), start)
        return i

    # Without a usable ETag every part is fetched; with one, only parts that
    # are all zeros (holes) or whose md5 is unknown get a second look below.
    todo = []
    for i in range(count):
        n = min(PART, size - i * PART)
        if not any(os.pread(fd, n, i * PART)):
            todo.append(i)
    if not nparts:
        todo = list(range(count))

    def run(parts, label):
        if not parts:
            return
        print("%s: %d of %d parts" % (label, len(parts), count), flush=True)
        done = 0
        with cf.ThreadPoolExecutor(WORKERS) as pool:
            for _ in pool.map(fetch, parts):
                done += 1
                if done % 10 == 0 or done == len(parts):
                    print("  %d / %d" % (done, len(parts)), flush=True)

    run(todo, "fetch")
    if not nparts:
        os.close(fd)
        print("no multipart ETag; size %d only" % size)
        return 0

    for round_ in range(3):
        md5s = [part_md5(fd, i, size) for i in range(count)]
        got = hashlib.md5(b"".join(md5s)).hexdigest()
        if got == want_md5:
            os.close(fd)
            print("verified %s (ETag %s)" % (out, etag))
            return 0
        # Unknown which part is bad: refetch any part with a zero run of 4 KiB,
        # then everything on the last round.
        bad = []
        for i in range(count):
            n = min(PART, size - i * PART)
            data = os.pread(fd, n, i * PART)
            if b"\0" * 4096 in data:
                bad.append(i)
        if round_ == 2 or not bad:
            bad = list(range(count))
        run(bad, "refetch")
    os.close(fd)
    print("ETag mismatch for %s" % out, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
