#!/usr/bin/env sh
set -euo

if [ "$#" -eq 0 ]
then 
    FEATURE=$(git rev-parse --abbrev-ref HEAD | awk -F"/" '{print tolower($2)}')
    ORIGIN=$(basename -s .git $(git config --get remote.origin.url))
else
    FEATURE=$1
    ORIGIN="custom"
fi

DEPLOYMENT_NAME="$FEATURE"
CLUSTER_ID="cl9hljjl80wg80ty9br8d9qj4"
WORKSPACE_ID="Not Set Yet"
WORKLOAD_ID="arn:aws:iam::364189071156:role/astronomer_resources_service_role"
ECR_URI="364189071156.dkr.ecr.us-west-2.amazonaws.com"
BASE_DIR=$PWD
ASTRO_DIR=$([ -d astro ] && echo $PWD/astro || echo $BASE_DIR)
ASTRO_IMAGE=$(awk '/^FROM/ {print $2; exit}' $ASTRO_DIR/Dockerfile)
ASTRO_IMAGE_VERSION=$(awk '/astro-runtime-version/ {split($0, a, " "); print a[3]; exit}' $ASTRO_DIR/Dockerfile)
DEPLOYMENT_RUNTIME=$ASTRO_IMAGE_VERSION
CONTAINER_RT=$(command -v podman >/dev/null 2>&1 && echo podman || echo docker)
env_file="NOT SET"


step(){
    echo
    echo
    printf "=%.0s" $(seq 1 79) && printf "\n"
    echo $1
    printf "=%.0s" $(seq 1 79) && printf "\n"
    echo 
    echo
}


decolor(){
    sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g"
}


astro_login(){
    step "Login"
    [ "$(uname)" != "Darwin" ] && astro login -t $ASTRO_TOKEN || true
}


start_podman(){
    [ "$CONTAINER_RT" != "podman" ] && return 0
    step "Start Podman machine if needed"
    if [ "$(uname)" = "Darwin" ]; then
        status=$($CONTAINER_RT machine list --format "{{.Running}}" --noheading | head -n1)
        if [ "$status" != "true" ]; then
            echo "Starting podman machine..."
            $CONTAINER_RT machine start
        else
            echo "Podman machine is already running ✓"
        fi
    fi
}


get_workspace_id(){
    WORKSPACE_ID=$(astro workspace list | awk '$0 ~ /data-sandbox/ {print $3}')
}


switch_workspace(){
    step "Use WORKSPACE: $WORKSPACE_ID"

    astro workspace switch $WORKSPACE_ID
    astro workspace list
}


set_env(){
    step "Set ENV"
    case $ORIGIN in
        "astronomer_dataeng")
            env_file=".env/.env"
            break
            ;;
        "astronomer_ingestor")
            env_file=".env.sandbox"
            break
            ;;
        "data-mapquest")
            env_file=".env.development"
            break
            ;;
        "datasol")
            env_file=".env/.env"
            break
            ;;
        "custom")
            env_file=".env.development"
            break
            ;;
        *)
            echo "Wrong origin: '$ORIGIN'"
            exit 127
            ;;
    esac
    cat $ASTRO_DIR/$env_file
}


create_deployment(){
    step "Create deployment: $DEPLOYMENT_NAME , workspace: $WORKSPACE_ID , runtime: $DEPLOYMENT_RUNTIME"
    set -x
    astro deployment create \
        --name="$DEPLOYMENT_NAME" \
        --description="Sandbox for $DEPLOYMENT_NAME" \
        --dag-deploy="enable" \
        --cluster-id="$CLUSTER_ID" \
        --workspace-id="$WORKSPACE_ID" \
        --runtime-version="$DEPLOYMENT_RUNTIME" \
        --scheduler-size="small" \
        --workload-identity="$WORKLOAD_ID" \
        --development-mode="enable" \
        --type="dedicated"
    set +x
}


wait_deployment(){
    step "Wait for deplyment $DEPLOYMENT_NAME become healthy"

    while true
    do
        status=$(astro deployment inspect --deployment-name $DEPLOYMENT_NAME | awk '/status/ {print $2; exit}')
        echo "$(date +"%T") -> $status"
        [ $status = "UNHEALTHY" ] && exit 127
        [ $status = "HEALTHY" ] && break || sleep 5
    done
}


add_variable(){
    step "Add variables from .env"

    set -x
    astro deployment variable create \
        --deployment-name "$DEPLOYMENT_NAME" \
        --workspace-id "$WORKSPACE_ID" \
        --load \
        --env $env_file
    set +x
}


add_update_worker_queue(){
    step "Update/create worker queues"
    set -x
    astro deployment worker-queue update \
        --deployment-name "$DEPLOYMENT_NAME" \
        --name "default" \
        --worker-type "A5" \
        --min-count 0 \
        --max-count 1 \
        --concurrency 8 \
        --force
    set +x
}



enable_dag_deploy(){
    step "Enable dag deploy"
    set -x
    astro deployment update \
        --deployment-name "$DEPLOYMENT_NAME" \
        --dag-deploy "enable"
    set +x
}


ecr_login(){
    step "Login to ECR"
    aws ecr get-login-password --profile system1 | $CONTAINER_RT login --username AWS --password-stdin $ECR_URI
}


update_astro_base_image(){
    step "Pull Astro base image"
    #image="$ECR_URI/deng/astronomer:$ASTRO_IMAGE_VERSION"
    #podman pull $image
    $CONTAINER_RT pull $ASTRO_IMAGE
}


deploy(){
    step "Initial full deploy"

    cd $ASTRO_DIR
    set -x
    astro deploy \
        --deployment-name "$DEPLOYMENT_NAME" \
        --workspace-id "$WORKSPACE_ID" \
        --verbosity "info" \
        --force
    set +x

    cd $BASE_DIR
}


main(){
    #astro_login
    start_podman
    get_workspace_id
    switch_workspace
    set_env
    create_deployment
    wait_deployment
    add_variable
    add_update_worker_queue
    enable_dag_deploy
    ecr_login
    update_astro_base_image
    deploy
}


main
