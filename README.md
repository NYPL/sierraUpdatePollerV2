# SierraUpdatePoller v2

[![Build Status](https://travis-ci.com/NYPL/sierraUpdatePollerV2.svg?token=Fv4twsPZbkerqgdJB89v&branch=main)](https://travis-ci.com/NYPL/sierraUpdatePollerV2)

[![GitHub version](https://badge.fury.io/gh/nypl%2FsierraUpdatePollerV2.svg)](https://badge.fury.io/gh/nypl%2FsierraUpdatePollerV2)

This function polls the Sierra API for updates to the Bib, Holding and Item tables and passes them to a Kinesis stream for further processing. This function is largely a refactoring of the existing [SierraUpdatePoller](https://github.com/NYPL-discovery/sierraupdatepoller) but is somewhat simplified using the knowledge gained there.

## Requirements

- ruby 2.7
- AWS CLI

## Dependencies

- nypl_ruby_util@0.0.2
- aws-sdk-s3@1.74.0
- rspec@3.9.0
- mocha@1.11.2

## Environment Variables

- RECORD_TYPE: Type of records to poll, should be one of: `holdings`, `bibs`, or `items`
- RECORD_FIELDS: Comma delimited list of fields to retrieve for the record type
- SCHEMA_TYPE: The name of the Avro schema that records will be encoded with
- KINESIS_STREAM: Destination stream for the retrieved records
- LOG_LEVEL: Standard logging level. Defaults to INFO
- S3_AWS_REGION: Necessary for connecting to S3
- NYPL_CORE_S3_BASE_URL: Should always be `https://s3.amazonaws.com`
- BUCKET_NAME: Name of bucket where state is stored as JSON documents
- SIERRA_API_BASE_URL: Base URI for the Sierra API
- SIERRA_VERSION: Version of the Sierra API to use in this environement
- SIERRA_OAUTH_URL: URI for the Sierra API authentication endpoint
- SIERRA_OAUTH_ID: SENSITIVE, encoded ID for the Sierra API
- SIERRA_OAUTH_SECRET: SENSITIVE, encoded secret key for the Sierra API

## Installation

This function is developed using the AWS SAM framework, [which has installation instructions here](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)

To install the dependencies for this function, they must be bundled for this framework and should be done with `rake run_bundler`

## Usage

To run the function locally it may be invoked with rake, where FUNCTION is the name of the function you'd like to invoke from the `sam.local.yml` file:

`rake run_local[FUNCTION]`

## Testing

Testing is provided via `rspec` with `mocha` for stubbing/mocking. The test suite can be invoked with `rake test`
