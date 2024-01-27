# Requires Python 3.6

import xml.etree.ElementTree as ET
from arguments import Arguments
import sys
import re
from os import path, listdir

args = Arguments(sys.argv)

def xmlpretty(xmltext):
  return re.sub(r'(>)(<)',r'\1\n\2',re.sub(r'(<\/[^>]+>)',r'\1\n',xmltext))

def usage():
  print("usage: usanalyze.py -f <source-file> -o <list|view> [-p] [-i <sys_id>]")
  print("")
  print("    -f    Source Update Set XML file")
  print("")
  print("    -o    Operation to perform on data source")
  print("          'list' => list individual updates in set/repo")
  print("          'view' => view specific update identified by sys_id (requires -i)")
  print("")
  print("    -i    Specifies the sys_id to be viewed (required by '-o view')")
  print("    -p    Enables pretty XML output")
  sys.exit()

if not args.Get('f') or not args.Get('o'):
  usage()
  sys.exit()

if not path.isfile(args.Get('f')):
  print("File not found ({})".format(args.Get('f')))
  usage()
  
usxml = ET.parse(args.Get('f'))

if args.Get('o') == 'list':
  for thisupdate in usxml.getroot().findall('./sys_update_xml'):
    print("{} (sys_id = {})".format(re.sub('_[0-9a-fA-F]{32}','',thisupdate.find('./name').text),thisupdate.find('./sys_id').text))
elif args.Get('o') == 'view' and args.Get('i'):
  if args.Get('p'):
    print(xmlpretty(usxml.getroot().findall('./sys_update_xml[sys_id="{}"]/payload'.format(args.Get('i')))[0].text))
  else:
    print(usxml.getroot().findall('./sys_update_xml[sys_id="{}"]/payload'.format(args.Get('i')))[0].text)
else:
  print("Invalid arguments")
  usage()