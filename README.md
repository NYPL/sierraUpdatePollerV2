# SierraUpdatePoller v2

This function polls the Sierra API for updates to the Bib, Holding and Item tables and passes them to a Kinesis stream for further processing. This function is largely a refactoring of the existing [SierraUpdatePoller](https://github.com/NYPL-discovery/sierraupdatepoller) but is somewhat simplified using the knowledge gained there.

## Requirements

- ruby 2.7

## Dependencies

- nypl_ruby_util (under development, no releases yet)
- aws-sdk-s3@1.74.0

## Environment Variables

- RECORD_TYPE: Type of records to poll, should be one of: `holdings`, `bibs`, or `items`
- RECORD_FIELDS: Comma delimited list of fields to retrieve for the record type
- KINESIS_STREAM: Destination stream for the retrieved records
- LOG_LEVEL: Standard logging level. Defaults to INFO
- AWS_REGION: Necessary for connecting to S3
- NYPL_CORE_S3_BASE_URL: Should always be https://s3.amazonaws.com
- BUCKET_NAME: Name of bucket where state is stored as JSON documents
- SIERRA_API_BASE_URL: Base URI for the Sierra API
- SIERRA_VERSION: Version of the Sierra API to use in this environement
- SIERRA_OAUTH_URL: URI for the Sierra API authentication endpoint
- SIERRA_OAUTH_ID: SENSITIVE, encoded ID for the Sierra API
- SIERRA_OAUTH_SECRET: SENSITIVE, encoded secret key for the Sierra API

## Installation

This function is developed using the AWS SAM framework, [which has installation instructions here](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)

To install the dependencies for this function, they must be bundled for this framework and should be done with `bundle install --no-deployment; bundle install`

## Usage

To run the function locally it may be invoked with:

``` bash
echo '{"message": "testing"}' | sam local invoke SierraHoldingsUpdatePoller -t sam.local.yml
```

The `echo`ed message mimics a CloudWatch event which is what will be used to trigger this function

## Testing

### TODO

A test suite has not been implemented yet but will be done via `rspec`
