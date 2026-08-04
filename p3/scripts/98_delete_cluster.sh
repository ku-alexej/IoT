#!/bin/bash
set -e

printf "\nDeleting k3d cluster \"p3-cluster\".\n"
k3d cluster list | grep -qw "p3-cluster" && k3d cluster delete p3-cluster
printf "Cluster \"p3-cluster\" was deleted.\n\n"
