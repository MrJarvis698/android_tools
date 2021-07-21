#!/usr/bin/bash
echo "Enter Device Brand Name. eg.xiaomi"
read device_brand_name
echo "Enter Device Code Name. eg.lavender/excalibur"
read device_codename
echo "$device_brand_name"
echo "$device_codename"
read dumps_path
vendor_dir_name="vendor_$device_brand_name""_""$device_codename"

source $(pwd)/vendor_extract_vars.sh

vendor_dir (){
	mkdir $vendor_dir_name
	echo "$vendor_dir_name created."
	cd $vendor_dir_name
	git init
	apache_license
	vendor_template
	cd ..
	source $(pwd)/extract.sh
}

if ls $vendor_dir_name 1> /dev/null 2>&1; then
	echo "$vendor_dir_name Already Present"
	rm -rf $(pwd)/$vendor_dir_name
	vendor_dir
else
	vendor_dir
fi
#cd "vendor_$device_brand_name""_""$device_codename"
