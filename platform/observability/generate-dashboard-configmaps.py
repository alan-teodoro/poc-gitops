#!/usr/bin/env python3
"""
Generate Kubernetes ConfigMaps for Grafana dashboards.
This script reads JSON dashboard files and creates ConfigMaps with the grafana_dashboard label
for automatic import into OpenShift Grafana.
"""

import json
import yaml
import os
from pathlib import Path

# Dashboard configurations
DASHBOARDS = [
    {
        "name": "redis-cluster-dashboard",
        "file": "redis-cluster-dashboard.json",
        "title": "Redis Enterprise Cluster Dashboard"
    },
    {
        "name": "redis-database-dashboard",
        "file": "redis-database-dashboard.json",
        "title": "Redis Enterprise Database Dashboard"
    },
    {
        "name": "redis-node-dashboard",
        "file": "redis-node-dashboard.json",
        "title": "Redis Enterprise Node Dashboard"
    },
    {
        "name": "redis-shard-dashboard",
        "file": "redis-shard-dashboard.json",
        "title": "Redis Enterprise Shard Dashboard"
    }
]

def create_configmap(dashboard_config):
    """Create a ConfigMap YAML for a dashboard."""
    dashboard_file = Path("dashboards") / dashboard_config["file"]
    
    # Read the dashboard JSON
    with open(dashboard_file, 'r') as f:
        dashboard_json = f.read()
    
    # Create ConfigMap structure
    configmap = {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
            "name": f"grafana-dashboard-{dashboard_config['name']}",
            "namespace": "openshift-monitoring",
            "labels": {
                "grafana_dashboard": "1"
            },
            "annotations": {
                "description": dashboard_config['title']
            }
        },
        "data": {
            f"{dashboard_config['name']}.json": dashboard_json
        }
    }
    
    return configmap

def main():
    """Generate all ConfigMaps."""
    output_file = "grafana-dashboards-configmaps.yaml"
    
    print(f"Generating ConfigMaps for {len(DASHBOARDS)} dashboards...")
    
    configmaps = []
    for dashboard in DASHBOARDS:
        print(f"  - Processing {dashboard['title']}...")
        cm = create_configmap(dashboard)
        configmaps.append(cm)
    
    # Write all ConfigMaps to a single YAML file
    with open(output_file, 'w') as f:
        f.write("---\n")
        f.write("# Grafana Dashboards ConfigMaps\n")
        f.write("# Purpose: Official Redis Enterprise dashboards for automatic import\n")
        f.write("# Source: https://github.com/redis-field-engineering/redis-enterprise-observability\n")
        f.write("# Label: grafana_dashboard=1 enables automatic import in OpenShift Grafana\n")
        f.write("---\n")
        for i, cm in enumerate(configmaps):
            if i > 0:
                f.write("\n---\n")
            yaml.dump(cm, f, default_flow_style=False, sort_keys=False)
    
    print(f"\n✅ Generated {output_file} with {len(configmaps)} ConfigMaps")
    print(f"\nTo apply:")
    print(f"  oc apply -f {output_file}")

if __name__ == "__main__":
    main()

