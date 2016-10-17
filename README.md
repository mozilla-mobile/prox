# prox

## Installation
Install Cocoapods. If you already have Cocoapods installed, run the same
command to update:

    sudo gem install cocoapods

If it has been a while since you last updated Cocoapods, you may want to update
your pods spec repo (this can take some time):

    pod repo update

Install Pods:

    pod install

Open the workspace. You will need to use the workspace to do development from
now on. Attempting to compile the .xcodeproj by itself will result in
compilation failures:

    open Prox.xcworkspace
