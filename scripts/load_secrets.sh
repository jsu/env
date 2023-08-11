#!/usr/bin/env sh

get_secret(){
    secret_id=$1
    echo $(aws secretsmanager get-secret-value --secret-id "${secret_id}" --output json | jq ".SecretString" -r)
}

export DATAOPS_DSN=$(get_secret "etl/astro/dataops/prod1")
export DATADEV_DSN=$(get_secret "etl/astro/datadev/system1-ingestor-prod")
export GOOGLE_SHEETS_CREDS=$(get_secret "dataeng/gcp/etl-reports/gsheet-ingest/serviceaccount")


get_snowflake_dsn(){
    secret=$(get_secret "snowflake/account=etl_user")
    username=$(echo ${secret} | jq ".username" -r)
    password=$(echo ${secret} | jq ".password" -r)
    echo "snowflake://${username}:${password}@bz56129/ETL_MAIN/PUBLIC?warehouse=S1_ETL"
}
export SNOWFLAKE_ETL_DSN=$(get_snowflake_dsn)
