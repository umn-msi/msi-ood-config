# msi-ood-config

## announcments

Each file placed in `./announcments` will be its own announcement in the Open OnDemand app. These can either be markdown
or .yml files. The .yml files will be run through ERB.

## apps

You can override settings for installed apps by placing files in apps, this only really makes sense for the built-in
dashboard/shell/files apps. Any MSI apps should just be edited directly.

## public

Files in public will be reachable at https://ood.msi.umn.edu/public

## MOTD.md

This file will be included on the Open OnDemand homepage as the main body.
