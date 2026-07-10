package schemas

import (
	"list"
	"strings"
)

#AllotmentConfig: {
	apiVersion: "apiextensions.crossplane.io/v1beta1"
	kind:       "EnvironmentConfig"
	metadata: {
		name: "allotment-config"
		...
	}
	data: {
		provider:  "aws" | "gcp"
		projectId: string
		region:    string & =~"^[a-z][a-z0-9-]*[0-9]$"
		zones: [...string] & list.UniqueItems
		clusterName: string & =~"^[a-z0-9]([a-z0-9-]{0,43}[a-z0-9])?$"
		createdBy?:  string & strings.MaxRunes(63) & =~"^[a-z0-9_-]+$"
		expiresAt?:  string & =~"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
		dnsDomain:   string & strings.MaxRunes(240) &
				=~"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$"
		createShoot: "true" | "false"

		awsProfile?:        string
		awsGardenlinuxAmi?: string
		awsNodesPerZone?:   int & >0
		vpcNetwork?:        string
		gcpNodesPerZone?:   int & >0

		if provider == "aws" {
			projectId: string & =~"^[0-9]{12}$"
			zones: [...string & =~("^" + region + "[a-z]$")] &
				list.MinItems(2) & list.MaxItems(4)
			awsGardenlinuxAmi: string & =~"^ami-([0-9a-f]{8}|[0-9a-f]{17})$"
		}

		if provider == "gcp" {
			projectId: string & =~"^[a-z][a-z0-9-]{4,28}[a-z0-9]$"
			zones: [...string & =~("^" + region + "-[a-z]$")] & list.MinItems(1)
			vpcNetwork: string & =~"^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$"
		}
	}
}
