#!/usr/bin/env bash

while getopts m:s:o:t:i:n: flag
do
    case "${flag}" in
        m) mapping_file=${OPTARG};;
        s) script=${OPTARG};;
        o) output=${OPTARG};;
        n) output_template_name=${OPTARG};;
        i) input_template=${OPTARG};;
        t) template_type=${OPTARG};;
        *) exit 1;;
    esac
done

echo "In make archives"
SCRIPT_SOURCE=${BASH_SOURCE[0]/%makeArchives.sh/}
mkdir -p "${output}"
node "${SCRIPT_SOURCE}compiler.js" "${input_template}" "${mapping_file}" "${script}"  "${template_type}" "${SCRIPT_SOURCE}../script_url.txt" > "${output}${output_template_name}"
