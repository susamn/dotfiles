#!/bin/bash
docker ps --format "{{.ID}}|{{.Names}}|{{.Ports}}|{{.Status}}" | awk -F'|' '{
    id=substr($1,1,6)
    name=substr($2,1,12)
    ports=$3
    status=$4
    gsub(/0.0.0.0:/, "", ports)
    gsub(/->.*/,"",ports)
    gsub(/ /,"",ports)
    gsub(/Up /,"",status)
    gsub(/ \(.*\)/,"",status)
    gsub(/ seconds?/,"s",status)
    gsub(/ minutes?/,"m",status)
    gsub(/ hours?/,"h",status)
    gsub(/ days?/,"d",status)
    gsub(/ weeks?/,"w",status)
    if(ports=="") ports="-"

    # Truncate ports if too long, add ellipsis
    if(length(ports) > 10) {
        ports = substr(ports,1,7) "..."
    }

    printf "%s|%-12s|%-10s|%s\n", id, name, ports, substr(status,1,6)
}' | head -5
