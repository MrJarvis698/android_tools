#!/usr/bin/bash

if ls $(pwd)/working 1> /dev/null 2>&1; then
	rm -rf working && mkdir working
	./tools/proprietary-files.sh $dumps_path
	mv $(pwd)/working/proprietary-files.txt $(pwd)/working/backup_proprietary-files.txt
fi

proprietary_filename="$(pwd)/working/backup_proprietary-files.txt"
rm -rf $(pwd)/working/temp && mkdir $(pwd)/working/temp
grep -n "# " $proprietary_filename | tee $(pwd)/working/temp/blobs_searching_name_list.txt
rm -rf $(pwd)/working/temp/line_numbers.txt
filename="$(pwd)/working/temp/blobs_searching_name_list.txt"
seperate_blobs_path="$(pwd)/working/seperate_blobs"
final_line_number="$(pwd)/working/temp/line_numbers.txt"


rm -rf $seperate_blobs_path && mkdir $seperate_blobs_path

while read -r line; do
	blobs_searching_name="$(grep -x "$line" $filename | head -n 1 | rev | cut -d: -f1 | rev )" # This prints like "# ADSP"
	blobs_name="$(grep -x "$line" $filename | head -n 1 | rev | cut -d: -f1 | head -c -3 | rev )" # This prints like "ADSP"
	line_no="$(grep -n "$blobs_searching_name" $proprietary_filename | head -n 1 | cut -d: -f1 )" # This prints line no.
	if [[ $blobs_searching_name == "$(grep -x "$blobs_searching_name" $proprietary_filename)" ]]; then
		line_no="$(grep -n "$blobs_searching_name" $proprietary_filename | head -n 1 | cut -d: -f1 )"
		if [[ $blobs_searching_name == "$(sed -n '2,2p' $proprietary_filename)" ]]; then
			first_line_no="$(grep -n "$blobs_searching_name" $proprietary_filename | head -n 1 | cut -d: -f1 )" 
			echo "$first_line_no" | tee -a $final_line_number
		
		elif [[ $blobs_searching_name != "$(sed -n '2,2p' $proprietary_filename)" ]]; then
			let "rest_line_no="$(grep -n "$blobs_searching_name" $proprietary_filename | head -n 1 | cut -d: -f1 )" - 1"
			echo "$rest_line_no" | tee -a $final_line_number
		fi	
	else
		echo "failed"
	fi
done < "$filename"

last_line_variable="$(tail -n 1 $proprietary_filename)"
last_line_variable_number="$(grep -n -x "$last_line_variable" $proprietary_filename | head -n 1 | cut -d: -f1 )"
echo "$last_line_variable_number"| tee -a $final_line_number
range="$(tail -n 1 $final_line_number)"
last_line_no="$(grep -n "$range" $final_line_number | head -n 1 | cut -d: -f1 )"

for i in `seq $last_line_no`
do
	first_blob=$i
	let "second_blob="$i" + 1"
	start_blobs="$(sed -n "$i","$i""p" $final_line_number)"
	second_start_blobs="$(sed -n "$second_blob","$second_blob""p" $final_line_number)"
	echo $start_blobs - $second_start_blobs

	line="$(sed -n "$i","$i""p" $filename)"
	blobs_name="$(grep -x "$line" $filename | head -n 1 | rev | cut -d: -f1 | head -c -3 | rev )" # This prints like "ADSP"
	echo $blobs_name
	final="$(sed "$start_blobs,$second_start_blobs! d;" $proprietary_filename)"
	echo "$final" | tee -a $(pwd)/working/seperate_blobs/"$blobs_name".txt
	echo "Ignore Errors - Blobs List has been Created."
done

while read -r line; do
	blobs_name="$(grep -x "$line" $filename | head -n 1 | rev | cut -d: -f1 | head -c -3 | rev )" # This prints like "ADSP"
	rm $(pwd)/working/proprietary-files.txt
	cp $seperate_blobs_path/"$blobs_name".txt $seperate_blobs_path/../proprietary-files.txt
	./tools/vendor_tree.sh $dumps_path
	cp -R vendor/$device_brand_name/$device_codename/proprietary $vendor_dir_name/proprietary
	echo "" >> vendor/$device_brand_name/$device_codename/$device_codename-vendor.mk
	echo "# $blobs_name"| tee -a $vendor_dir_name/$device_codename-vendor.mk
	tail -n +4 vendor/$device_brand_name/$device_codename/$device_codename-vendor.mk |tail +1 | tee -a $vendor_dir_name/$device_codename-vendor.mk
	tail -n +4 vendor/$device_brand_name/$device_codename/Android.bp | tee -a $vendor_dir_name/Android.bp
	cd $vendor_dir_name && git add . && git commit -s -m "$device_codename: $blobs_name blobs from stock" && cd -
done < "$filename"

rm -rf $(pwd)/working/proprietary-files.txt
mv $(pwd)/working/backup_proprietary-files.txt $(pwd)/working/proprietary-files.txt
