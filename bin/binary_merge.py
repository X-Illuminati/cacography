#!/bin/python
# version 4
# readinto a bytearray and choose fast or slow algo depending on command line
# argument.
# The fast algo's speed is highly dependent on the amount of agreement in the
# input files. If they are mostly the same, it will be very fast. If they are
# mostly different it could be slower than more naïve algorithms.
# The slow algo's speed is entirely dependent on the size of the input files.
# slow: use zip_longest in Input_Iter_Old and return individual tuples
# fast: use slices to create a binary tree in which Input_Iter_New will return
# the largest subtree that is identical from all inputs (eventually returning
# tuples of single bytes).

import argparse
from collections import Counter
import curses.ascii
import io
from itertools import zip_longest
import signal
import sys
from threading import Thread
import time

#globals
interrupt = 0
args=argparse.Namespace()
stats = {
    'equal_count': 0,
    'replace_zero_count': 0,
    'replace_first_count': 0,
    'zero_ignored_count': 0,
}

def _v():
    global args
    return args.verbose

def parse_args(inargs) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='This script will merge 2 or more binary files and display some statistics. Output is based on a majority rules consensus. If there is a tie for the majority, a 00 byte will be emitted.',
        )
    parser.add_argument('-f', '--prefer-first', action='store_true',
        help='when agreement can\'t be reached, use the content of the first file (unless it is too short)')
    parser.add_argument('-n', '--prefer-nonzero', action='store_true',
        help='exclude 00 bytes from the majority rules calculation')
    parser.add_argument('-q', '--quiet', action='store_true',
        help='supress output of statistics and progress')
    parser.add_argument('-s', '--slow', action='store_true',
        help='use the slower first-pass consensus algorithm (this algorithm is much slower in general, but may be faster for some degenerate, poorly-aligned inputs)')
    parser.add_argument('-v', '--verbose', action='store_true',
        help='extra output for debug')
    parser.add_argument('infiles', nargs='+', help='file names of input files')
    parser.add_argument('outfile', help='file name of output file')
    return(parser.parse_args(inargs))

class Input_Iter_New:
    def __init__(self, infiles):
        self.infiles=infiles
        self.buffers=list(bytearray(32768) for _ in infiles)
        self.btree=[]
        self.counter=0
        
    def __iter__(self):
        return self
        
    def __next__(self):
            try:
                s = self.btree.pop()
            except IndexError:
                self.load_buffers()
                s = self.btree.pop()
            return self.process(s[0], s[1])

    def load_buffers(self):
        self.btree=[]
        rcnt=[]
        for i,_ in enumerate(self.infiles):
            rcnt.append(_.readinto(self.buffers[i]))
            self.buffers[i]=self.buffers[i][0:rcnt[i]]
        m=max(rcnt)
        if (m == 0):
            raise StopIteration
        self.btree.append((0, m))

    def process(self, start, end):
        def check(self, s, e):
            if (e-s) <= 1:
                # special case, break out of the loop when down to 1 element
                return True
            else:
                return all(_[s:e]==self.buffers[0][s:e]
                    for _ in self.buffers[1:])

        while not check(self, start, end):
            mid = start + (end-start)//2
            self.btree.append((mid, end))
            end = mid

        size = end - start
        self.counter += size
        if (1 == size):
            if not all((bytes(_[start:end])==bytes(self.buffers[0][start:end])
                for _ in self.buffers[1:])):
                return tuple((_[start:end])[0] if _[start:end] else None
                    for _ in self.buffers)
        return self.buffers[0][start:end]

    def get_counter(self):
        return self.counter

class Input_Iter_Old:
    def __init__(self, infiles):
        self.infiles=infiles
        self.buffers=list(bytearray(32768) for _ in infiles)
        self.zip=zip_longest()
        self.counter=0
        self.zlen=0
        
    def __iter__(self):
        return self
        
    def __next__(self):
        global args
        try:
            ret=next(self.zip)
            if (_v()): self.counter += 1
        except StopIteration:
            if (not _v()): self.counter += self.zlen
            self.load_buffers()
            ret=next(self.zip)
        return ret

    def load_buffers(self):
        self.zip=None
        self.zlen=0
        rcnt=[]
        for i,_ in enumerate(self.infiles):
            rcnt.append(_.readinto(self.buffers[i]))
            self.buffers[i]=self.buffers[i][0:rcnt[i]]
        m=max(rcnt)
        if (m == 0):
            raise StopIteration
        self.zip = zip_longest(*self.buffers)
        self.zlen = m

    def get_counter(self):
        return self.counter

def do_merge(values, fileiter) -> bytes:
    global args
    global stats

    if isinstance(values, bytearray):
        #special case, we already have agreement
        stats['equal_count'] += len(values)
        return values

    c = Counter(values)

    del c[None] #filter out empties

    if (len(c) == 1):
        stats['equal_count'] += 1 #complete consensus
        # values[0] might be None, instead use the single "most common" value
        # from the collection
        return bytes([c.most_common(1)[0][0]])

    #filter out 0s (unless 0 was the only item)
    if (args.prefer_nonzero) and (c.most_common(1)[0][0] == 0):
        del c[0]
        stats['zero_ignored_count'] += 1

    m = c.most_common(2)
    ret = m[0][0]
    if (len(m)>1) and (m[0][1] == m[1][1]):
        #no consensus
        if (args.prefer_first) and (values[0] != None):
            ret = values[0]
            stats['replace_first_count'] += 1
        else:
            ret = 0
            stats['replace_zero_count'] += 1

    if (_v()):
        xlen = len(hex(stats['maxlen']))-2
        print("<{:{}x}: {:#04x} from {}".format(fileiter.get_counter(), xlen, ret, values))

    return bytes([ret]) #additional return statement above

def setup_timer(infiles):
    global args
    global stats

    timerval = 2.0
    if (_v()):
        timerval=0.1
    def status():
        while True:
            time.sleep(timerval)
            address = max(tuple(_.tell() for _ in infiles))
            slen = len(str(stats['maxlen']))
            bslen = slen*2+17
            print("{}{:{}d} / {:d} ({:%})".format(
                chr(curses.ascii.BS)*bslen,
                address, slen,
                stats['maxlen'],
                address / stats['maxlen'],
                ),
                end=chr(curses.ascii.BS)*bslen, flush=True)
    t = Thread(target=status)
    t.daemon = True
    t.start()

def print_stats():
    global args
    global stats

    print()
    print("Bytes with complete consensus: {} ({:%})".format(
        stats['equal_count'],
        stats['equal_count'] / stats['maxlen'],
        ))
    if (args.prefer_nonzero):
        print("Bytes where 0x00 was ignored: {} ({:%})".format(
            stats['zero_ignored_count'],
            stats['zero_ignored_count'] / stats['maxlen'],
            ))
    if (args.prefer_first):
        print("Bytes that defaulted to first file value: {} ({:%})".format(
            stats['replace_first_count'],
            stats['replace_first_count'] / stats['maxlen'],
            ))
    print("Bytes that defaulted to 0x00: {} ({:%})".format(
        stats['replace_zero_count'],
        stats['replace_zero_count'] / stats['maxlen'],
        ))

def main(inargs) -> int:
    global args
    global stats
    global interrupt

    args=parse_args(inargs)
    if (_v()):
        print(args)
        if (args.quiet):
            print("Use of quiet and verbose together is nonsensical!")
            return 1

    infiles=tuple(io.open(_, 'rb') for _ in args.infiles)
    stats['filelen']=tuple(_.seek(0, io.SEEK_END) for _ in infiles)
    for _ in infiles:
        _.seek(0, io.SEEK_SET)
    stats['maxlen']=max(stats['filelen'])
    if (_v()):
        print(stats['filelen'], stats['maxlen'])

    with open(args.outfile, 'wb') as outfile:
        if (not args.quiet):
            setup_timer(infiles)

        if args.slow:
            fileiter = Input_Iter_Old(infiles)
        else:
            fileiter = Input_Iter_New(infiles)
        for _ in fileiter:
            if interrupt:
                break
            val = do_merge(_, fileiter)
            if (len(val) < 1):
                raise AssertionError("Write of 0 bytes (val={})".format(val))
            out = outfile.write(val)
            if (len(val) != out):
                raise AssertionError("Write of {} bytes (val={}) failed with return {} at {}".format(len(val), val,out,fileiter.get_counter()))

    if (not args.quiet):
        print_stats()
    return interrupt

def interrupt_handler(signum, frame):
    global interrupt
    interrupt = 130

if __name__ == '__main__':
    signal.signal(signal.SIGINT, interrupt_handler)
    sys.exit(main(sys.argv[1:]))
