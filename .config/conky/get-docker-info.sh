#!/bin/bash
docker ps --format "{{.ID}}|{{.Names}}|{{.Ports}}|{{.Status}}" | awk -F'|' '{
    id=substr($1,1,6)
    name=substr($2,1,15)
    ports=$3
    status=$4
    gsub(/0.0.0.0:/, "", ports)
    gsub(/->.*/,"",ports)
    gsub(/Up /,"",status)
    gsub(/ \(.*\)/,"",status)
    gsub(/ seconds?/,"s",status)
    gsub(/ minutes?/,"m",status)
    gsub(/ hours?/,"h",status)
    gsub(/ days?/,"d",status)
    gsub(/ weeks?/,"w",status)
    if(ports=="") ports="-"
    printf "%s | %s | %s | %s\n", id, name, substr(ports,1,10), substr(status,1,8)
}' | head -5
