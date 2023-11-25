#!/bin/bash

# Define your registry and available build stages
REGISTRY="doduo1.umcn.nl/daangeijs/pathologydocker"
STAGES=("cpu" "pytorch" "tensorflow")

# Ask for the build stage
echo "Enter the build stage (cpu, pytorch, tensorflow) or press enter to build all:"
read BUILD_STAGE

build_and_push() {
    local stage=$1
    echo "Enter the version for $stage:"
    read VERSION
    if [ -z "$VERSION" ]; then
        echo "Version is required. Skipping $stage."
        return
    fi

    TAG="$REGISTRY:$stage-$VERSION"
    LATEST_TAG="$REGISTRY:$stage-latest"

    echo "Building $TAG..."
    docker build --target $stage -t $TAG -f Dockerfile .
    docker tag $TAG $LATEST_TAG
    echo "Pushing $TAG and $LATEST_TAG..."
    docker push $TAG
    docker push $LATEST_TAG
}

if [ -z "$BUILD_STAGE" ]; then
    # Build all stages
    for stage in "${STAGES[@]}"; do
        build_and_push $stage
    done
else
    # Build specific stage
    if [[ " ${STAGES[*]} " == *" $BUILD_STAGE "* ]]; then
        build_and_push $BUILD_STAGE
    else
        echo "Invalid stage: $BUILD_STAGE"
    fi
fi
