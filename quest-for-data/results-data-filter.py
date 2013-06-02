#!/usr/bin/env python

"""accept a JSON file (or stdin) from the BEA web service; extract the
useful data from the response's wrapper and emit formatted JSON

Usage:
    ./results-data-filter my-bea-results.json
    
    -or-
    
    http GET "http://www.bea.gov/api/data/?&UserID={my-api-key}&method=getdata&datasetname=RegionalData&keycode=PCPI_CI&year=2011&geofips=county" | ./results-data-filter.py > PCPI_CI_2011.json

"""

import sys
import optparse
import json
import functools


def compose(*fns):
    def compose2(f, g):
        return lambda x: f(g(x))
    return functools.reduce(compose2, fns)


def noop(x):
    return x


def numerifier(colname):
    def numerify(key, val):
        return int(val) if key == colname else val
    def numerify_col(row):
        return {k: numerify(k, v) for k, v in row.items()}
    return numerify_col
    

def col_renamer(orig_name, new_name):
    def namer(colname):
        return new_name if colname == orig_name else colname
    def rename_row(row):
        return {namer(k): v for k, v in row.items()}
    return rename_row


def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]
    parser = optparse.OptionParser()
    # add options here
    # ...
    parser.add_option('-n', '--numerify', dest='should_numerify', action='store_false', default=True,
        help='convert the DataValue column to a number')
    parser.add_option('', '--data-value-column-name', dest='data_value_column_name',
        default='DataValue', help='new name for the DataValue column')
    opts, args = parser.parse_args(argv)

    readable = open(args[0]) if args else sys.stdin
    data = json.loads(readable.read())
    data = data['BEAAPI']['Results']['Data']
    transformer = compose(
        col_renamer('DataValue', opts.data_value_column_name),
        numerifier('DataValue'))
    data = [transformer(row) for row in data]
    print json.dumps(data, indent=4, sort_keys=True)
    

if __name__ == '__main__':
    sys.exit(main())
