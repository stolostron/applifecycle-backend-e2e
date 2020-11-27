

cleanup_application_operator(){
    echo "Clean the channel repo"
    if [ -d "multicloud-operators-application" ]; then
        kubectl delete -f multicloud-operators-application/deploy/crds
    fi

}

cleanup_channel_operator(){
    echo "Clean up the channel repo"
    if [ -d "multicloud-operators-channel" ]; then
        kubectl delete -f multicloud-operators-channel/deploy/standalone
    fi
}

cleanup_subscription_operator(){
    echo "Clean up the subscription repo"
    if [ -d "multicloud-operators-subscription" ]; then
        kubectl delete -f multicloud-operators-subscription/deploy/standalone
    fi

}

cleanup_placementrule_operator(){
    echo "Clean up the placementrule repo"
}

cleanup_helmrelease_operator(){
    echo "Clean up the helmrelease repo"
    if [ -d "multicloud-operators-subscription-release" ]; then
        kubectl delete -f multicloud-operators-subscription-release/deploy
    fi
}


cleanup_operators(){
    if [ "$1" == "channel" ]; then
        cleanup_channel_operator
    elif [ "$1" == "sub" ]; then
        cleanup_subscription_operator
    elif [ "$1" == "release" ]; then
        cleanup_helmrelease_operator
    elif [ "$1" == "placement" ]; then
        cleanup_placementrule_operator
    elif [ "$1" == "app" ]; then
        cleanup_application_operator
    else
        cleanup_application_operator
        cleanup_channel_operator
        cleanup_subscription_operator
        cleanup_helmrelease_operator
        cleanup_placementrule_operator
    fi
}

cleanup_operators $1
