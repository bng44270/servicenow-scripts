from arguments import Arguments
from sys import argv as command_args
from math import ceil as round_up

priority_map = {1:90.0,2:60.0,3:40.0,4:25.0,5:10.0}
severity_map = {1:95.0,2:55.0,3:25.0}
impact_map = {1:80.0,2:60.0,3:40.0}

ARGS = Arguments(command_args)

if not ARGS.Get('p') or not ARGS.Get('s') or not ARGS.Get('b'):
  print "usage: riskcalc.py -p <priority> -s <severity> -b <business-impact>"
else:
  try:
    score = int(round_up((priority_map[int(ARGS.Get('p'))] + severity_map[int(ARGS.Get('s'))] + impact_map[int(ARGS.Get('b'))]) / 3))
    print "Risk score = {}".format(score)
  except:
    print "Argument out of range (-p [1-5] -s [1-3] -b [1-3])"