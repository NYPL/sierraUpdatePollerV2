# SierraUpdatePoller v2

[![Build Status](https://travis-ci.com/NYPL/sierraUpdatePollerV2.svg?token=Fv4twsPZbkerqgdJB89v&branch=main)](https://travis-ci.com/NYPL/sierraUpdatePollerV2)

[![GitHub version](https://badge.fury.io/gh/nypl%2FsierraUpdatePollerV2.svg)](https://badge.fury.io/gh/nypl%2FsierraUpdatePollerV2)

This function polls the Sierra API for updates to the Bib, Holding, and Item tables and passes them to a Kinesis stream for further processing. This function is largely a refactoring of the existing [SierraUpdatePoller](https://github.com/NYPL-discovery/sierraupdatepoller) but is somewhat simplified using the knowledge gained there.

Note that the kinesis stream (and schema) used to broadcast fetched records differs depending on the record type:

 - **Updated/deleted bibs** are posted to the BibPostRequest Kinesis stream, encoded using the namesake schema ([see diagram](https://docs.google.com/presentation/d/1kPUhT-JPOuniXndKWc_JEp2EY5rOPuH5ebSqYCe_438/edit?slide=id.g3753bed0956_0_2#slide=id.g3753bed0956_0_2))
 - **Updated/deleted items** are posted to the ItemPostRequest Kinesis stream, encoded using the namesake schema ([see diagram](https://docs.google.com/presentation/d/1kPUhT-JPOuniXndKWc_JEp2EY5rOPuH5ebSqYCe_438/edit?slide=id.g3753bed0956_0_2#slide=id.g3753bed0956_0_2))
 - **Updated holdings** are posted to the SierraHoldingParser Kinesis stream, encoded using the SierraHolding schema so that we can attach checkin cards ([see diagram](https://docs.google.com/presentation/d/1Zo04SACodW9Q0mI4RBbpwoD-oFIrqCsjOAUtPaB0Grw/edit?slide=id.g96875acc9d_0_45#slide=id.g96875acc9d_0_45))
 - **Deleted holdings** are posted directly to the HoldPostRequest Kinesis stream (because we don't need to attach checkin cards to deleted holdings), encoded using the Holding schema ([see diagram](https://docs.google.com/presentation/d/1Zo04SACodW9Q0mI4RBbpwoD-oFIrqCsjOAUtPaB0Grw/edit?slide=id.g96875acc9d_0_45#slide=id.g96875acc9d_0_45))

Reconciling the multiple variaions of Holding schema and their inconsistent relationship to stream name is an acknowledged future improvement. It seems likely the `Holding` schema is flexible enough to be used everywhere we're currently using `HoldPostRequest` or `SierraHolding`, although our standard recommends revising the pipeline to ensure schema names match Kinesis stream names, even if that means some schemas are identical. We should move this in one or the other direction.

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
- SKIP_UPDATING_STATE_FILE: Set to 'true' to skip uploading S3 state file (for local testing)

## Installation

This function is developed using the AWS SAM framework, [which has installation instructions here](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-install.html)

To install the dependencies for this function, they must be bundled for this framework and should be done with:
```
bundle install    # To ensure aws-sdk is installed, as that's required by rakefile
rake run_bundler
```

## Usage

To run the function locally it may be invoked with rake, where FUNCTION is the name of the function you'd like to invoke from the `sam.local.yml` file:

`rake run_local[FUNCTION]`

One can also bypass the scheduled polling to run a "manual job" over a specific timestamp range. Note that doing this skips over reading/writing poller\_status files in S3. Note also that one must choose a timestamp range that can reasonably be processed within the lambda's configured max execution time (1m at writing).

```
sam local invoke -t sam.local.yml -e events/manual-job-event.json --profile nypl-sandbox
```

## Testing

Testing is provided via `rspec` with `mocha` for stubbing/mocking. The test suite can be invoked with `rake test`

## Contributing

1. Cut a feature branch off of development
2. Commit changes to your feature branch
3. File a pull request against devlopment and assign a reviewer
4. After the PR is accepted, merge into development
5. Merge development > qa. This triggers a QA deployment
6. Confirm app deploys to QA and run appropriate testing
7. Merge qa > main. This triggers a prod deployment.

## Deployment

This app uses Travis-CI and terraform for deployment. Code pushed to qa and main trigger deployments to qa and production, respectively.

Troubleshooting deployments
In the case that you need to make terraform aware of a lambda resource that was created outside of terraform, for example a Lambda previously created in a Travis Deployment, you can import the existing resource like this:

```
terraform -chdir=provisioning/{branch}/{record_update/delete} import module.base.aws_lambda_function.poller_lambda Sierra{Record}{Delete?}UpdatePoller-{branch}
```
