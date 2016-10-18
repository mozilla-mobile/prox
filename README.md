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

### GoogleServices-Info.plist
For a successful build, you need the `Prox/Prox/GoogleService-Info.plist` file
which contains secure information to connect to Firebase and our backend
services. *Please do not add this file to version control.*

If you are a team member, this file is available in the Engineering gdrive. If
you are not, please contact a team member directly to discuss receiving this
file for development.
