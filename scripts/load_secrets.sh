#!/usr/bin/env sh

get_secret(){
    secret_id=$1
    echo $(aws secretsmanager get-secret-value --secret-id "${secret_id}" --output json | jq ".SecretString" -r)
}

export datadev_dsn=$(get_secret "etl/astro/datadev/system1-ingestor-prod")
export dataops_dsn=$(get_secret "etl/astro/dataops/prod1")
export datasol_dsn=$(get_secret "etl/astro/datasol/prod1")
export google_sheets_creds=$(get_secret "dataeng/gcp/etl-reports/gsheet-ingest/serviceaccount")
export SNOWFLAKE=$(get_secret "snowflake/account=etl_user")
export snowflake_prometheus=$(get_secret "database/system1/prod/snowflake/deng/prometheus_user")


get_snowflake_dsn(){
    username=$(echo ${SNOWFLAKE} | jq ".username" -r)
    password=$(echo ${SNOWFLAKE} | jq ".password" -r)
    echo "snowflake://${username}:${password}@bz56129/ETL_MAIN/PUBLIC?warehouse=S1_ETL"
}
export SNOWFLAKE_ETL_DSN=$(get_snowflake_dsn)


export snowflake_prometheus_dsn=$(echo ${snowflake_prometheus} | jq ".dsn" -r)
