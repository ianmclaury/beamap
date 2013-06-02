"""one-off script to combine the result data from farm and non-farm incomes into one output file

Usage:
    python unify-incomes.py    # note! uses hardcoded input file names! see main() below
"""

import sys
import optparse
import json
import itertools
import operator


def indexed_data(json_file, data_column_name, index_column_name='GeoFips'):
    useful_fields = {'DataValue', 'GeoFips', 'GeoName', 'TimePeriod', 'DataValue'}
    column_map = dict(DataValue=data_column_name)
    value_map = dict(DataValue=int)
    
    def noop(x): return x
    
    with open(json_file) as f:
        raw = json.loads(f.read())
        data_rows = raw['BEAAPI']['Results']['Data']
    def fieldname(key):
        return column_map.get(key, key)
    def fieldvalue(key, value):
        return value_map.get(key, noop)(value)
    def filtered_dict(row):
        return {fieldname(k): fieldvalue(k, v) for k,v in row.items() if k in useful_fields}
    return dict((d[index_column_name], filtered_dict(d)) for d in data_rows)
    

def main(argv=None):
    if argv is None:
        argv = sys.argv[1:]
    parser = optparse.OptionParser()
    # add options here
    # ...
    opts, args = parser.parse_args(argv)
    
    # args should be (farm_income, nonfarm_income)
    farm_income = indexed_data('farm-income-2012.json', 'FarmIncome')
    nonfarm_income = indexed_data('nonfarm-income-2012.json', 'NonfarmIncome')
    
    merged = {}
    for fips, data in farm_income.items():
        merged[fips] = data.copy()
        merged[fips]['NonfarmIncome'] = nonfarm_income[fips]['NonfarmIncome']
    
    merged = sorted(merged.values(), key=operator.itemgetter('GeoFips'))
    print json.dumps(merged, indent=4, sort_keys=True)
    

if __name__ == '__main__':
    sys.exit(main())
