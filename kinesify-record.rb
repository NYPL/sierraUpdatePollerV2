# Attempt to avro-encode a jsonfile
#
# This really just tells you if the given object may be encoded 
#
# Usage: 
#   ruby kinesify-record SCHEMANAME JSONFILE
#
# e.g.
#   ruby kinesify-record SierraHolding samples/deleted-holding.json
#
# Note that this depends on :development gems, so you'll need to:
#   bundle config set with 'development'
#   bundle install

require "bundler/setup"
require "nypl_ruby_util"
require 'dotenv'

require 'dotenv/load'

def encode(record, schema_name)
  avro = NYPLAvro.by_name(schema_name)
  encoded = avro.encode(record, false)
  print encoded
end

envfile = './config/holding-qa.env'
Dotenv.load(envfile)

schema = ARGV[0]
file = ARGV[1]
input = JSON.load_file(file)
begin
  encode(input, schema)

  print "\nLooks good"
rescue AvroError => e
  print e
  print "\nError encoding"
end
