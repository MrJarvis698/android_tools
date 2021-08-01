#!/bin/bash

# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (C) 2019 Shivam Kumar Jha <jha.shivam3@gmail.com>
#
# Helper functions

# Store project path
PROJECT_DIR="$(pwd)"
dump_path="$1"

# Common stuff
source $PROJECT_DIR/helpers/common_script.sh

# Exit if no arguements
if [ -z "$1" ] ; then
    echo -e "Supply rom directory or system/build.prop as arguement!"
    exit 1
fi

for var in "$@"; do
    unset BRAND_TEMP BRAND DEVICE DESCRIPTION FINGERPRINT MODEL PLATFORM SECURITY_PATCH VERSION FLAVOR ID INCREMENTAL TAGS
    # Dir or file handling
    if [ -d "$var" ]; then
        DIR=$( realpath "$var" )
        rm -rf $PROJECT_DIR/working/system_build.prop
        find "$DIR/" -maxdepth 3 -name "build*prop" -exec cat {} >> $PROJECT_DIR/working/system_build.prop \;
        if [[ -d "$DIR/vendor/euclid/" ]]; then
            EUCLIST=`find "$DIR/vendor/euclid/" -name "*.img" | sort`
            for EUCITEM in $EUCLIST; do
                7z x -y $EUCITEM -o"$PROJECT_DIR/working/euclid" > /dev/null 2>&1
                [[ -d "$PROJECT_DIR/working/euclid" ]] && find "$PROJECT_DIR/working/euclid" -name "*prop" -exec cat {} >> $PROJECT_DIR/working/system_build.prop \;
                rm -rf "$PROJECT_DIR/working/euclid"
            done
        fi
        CAT_FILE="$PROJECT_DIR/working/system_build.prop"
    elif echo "$var" | grep "https" ; then
        if echo "$var" | grep "all_files.txt" ; then
            wget -O $PROJECT_DIR/working/all_files.txt $var
            DUMPURL=$( echo ${var} | sed "s|/all_files.txt||1" )
            file_lines=`cat $PROJECT_DIR/working/all_files.txt | grep -iE "build" | grep -iE "prop" | sort -uf`
            for line in $file_lines ; do
                ((OTA_NO++))
                wget ${DUMPURL}/${line} -O $PROJECT_DIR/working/${OTA_NO}.prop > /dev/null 2>&1
            done
            find $PROJECT_DIR/working/ -name "*prop" -exec cat {} >> $PROJECT_DIR/working/system_build \;
            CAT_FILE="$PROJECT_DIR/working/system_build"
        else
            wget -O $PROJECT_DIR/working/system_build.prop $var
            CAT_FILE="$PROJECT_DIR/working/system_build.prop"
        fi
    else
        CAT_FILE="$var"
    fi

    #build.prop cleanup
    sed -i "s|ro.*\=QUALCOMM||g" "$CAT_FILE"
    sed -i "s|ro.*\=qssi||g" "$CAT_FILE"
    sed -i "s|ro.*\=qti||g" "$CAT_FILE"
    sed -i '/^$/d' "$CAT_FILE"
    sort -u -o "$CAT_FILE" "$CAT_FILE"

    # Set variables
    if grep -q "ro.product.odm.manufacturer=" "$CAT_FILE"; then
        BRAND_TEMP=$( cat "$CAT_FILE" | grep "ro.product.odm.manufacturer" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.product.product.manufacturer=" "$CAT_FILE"; then
        BRAND_TEMP=$( cat "$CAT_FILE" | grep "ro.product.product.manufacturer" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "odm.BRAND=" "$CAT_FILE"; then
        BRAND_TEMP=$( cat "$CAT_FILE" | grep "ro.product" | grep "odm.BRAND=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "BRAND=" "$CAT_FILE"; then
        BRAND_TEMP=$( cat "$CAT_FILE" | grep "ro.product" | grep "BRAND=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "manufacturer=" "$CAT_FILE"; then
        BRAND_TEMP=$( cat "$CAT_FILE" | grep "ro.product" | grep "manufacturer=" | sed "s|.*=||g" | head -n 1 )
    fi
    BRAND=$(echo $BRAND_TEMP | tr '[:upper:]' '[:lower:]')
    if grep -q "ro.vivo.product.release.name" "$CAT_FILE"; then
        DEVICE=$( cat "$CAT_FILE" | grep "ro.vivo.product.release.name=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.vendor.product.oem=" "$CAT_FILE"; then
        DEVICE=$( cat "$CAT_FILE" | grep "ro.vendor.product.oem=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.product.vendor.DEVICE=" "$CAT_FILE"; then
        DEVICE=$( cat "$CAT_FILE" | grep "ro.product.vendor.DEVICE=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "odm.DEVICE=" "$CAT_FILE"; then
        DEVICE=$( cat "$CAT_FILE" | grep "odm.DEVICE=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "DEVICE=" "$CAT_FILE" && [[ "$BRAND" != "google" ]]; then
        DEVICE=$( cat "$CAT_FILE" | grep "ro.product" | grep "DEVICE=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.product.system.name" "$CAT_FILE" && [[ "$BRAND" != "google" ]]; then
        DEVICE=$( cat "$CAT_FILE" | grep "ro.product.system.name=" | sed "s|.*=||g" | head -n 1 )
    fi
    [[ -z "$DEVICE" ]] && DEVICE=$( cat "$CAT_FILE" | grep "ro.build" | grep "product=" | sed "s|.*=||g" | head -n 1 )
    [[ -z "$DEVICE" ]] && DEVICE=$( cat "$CAT_FILE" | grep "ro." | grep "build.fingerprint=" | sed "s|.*=||g" | head -n 1 | cut -d : -f1 | rev | cut -d / -f1 | rev )
    [[ -z "$DEVICE" ]] && DEVICE=$( cat "$CAT_FILE" | grep "ro.target_product=" | sed "s|.*=||g" | head -n 1 | cut -d - -f1 )
    [[ -z "$DEVICE" ]] && DEVICE=$( cat "$CAT_FILE" | grep "build.fota.version=" | sed "s|.*=||g" | sed "s|WW_||1" | head -n 1 | cut -d - -f1 )
    DEVICE=$( echo ${DEVICE} | sed "s|ASUS_||g" )
    VERSION=$( cat "$CAT_FILE" | grep "build.version.release=" | sed "s|.*=||g" | head -c 2 | head -n 1 )
    re='^[0-9]+$'
    if ! [[ $VERSION =~ $re ]] ; then
        VERSION=$( cat "$CAT_FILE" | grep "build.version.release=" | sed "s|.*=||g" | head -c 1 | head -n 1 )
    fi
    FLAVOR=$( cat "$CAT_FILE" | grep "ro.build" | grep "flavor=" | sed "s|.*=||g" | head -n 1 )
    ID=$( cat "$CAT_FILE" | grep "ro.build" | grep "id=" | sed "s|.*=||g" | head -n 1 )
    INCREMENTAL=$( cat "$CAT_FILE" | grep "ro.build" | grep "incremental=" | sed "s|.*=||g" | head -n 1 )
    TAGS=$( cat "$CAT_FILE" | grep "ro.build" | grep "tags=" | sed "s|.*=||g" | head -n 1 )
    DESCRIPTION=$( cat "$CAT_FILE" | grep "ro." | grep "build.description=" | sed "s|.*=||g" | head -n 1 )
    [[ -z "$DESCRIPTION" ]] && DESCRIPTION="$FLAVOR $VERSION $ID $INCREMENTAL $TAGS"
    if grep -q "build.fingerprint=" "$CAT_FILE"; then
        FINGERPRINT=$( cat "$CAT_FILE" | grep "ro." | grep "build.fingerprint=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "build.thumbprint=" "$CAT_FILE"; then
        FINGERPRINT=$( cat "$CAT_FILE" | grep "ro." | grep "build.thumbprint=" | sed "s|.*=||g" | head -n 1 )
    fi
    [[ -z "$FINGERPRINT" ]] && FINGERPRINT=$( echo $DESCRIPTION | tr ' ' '-' )
    if echo "$FINGERPRINT" | grep -iE "nokia"; then
        BRAND="nokia"
        DEVICE=$( cat "$CAT_FILE" | grep "ro." | grep "build.fingerprint=" | sed "s|.*=||g" | head -n 1 | cut -d : -f1 | rev | cut -d / -f2 | rev | sed "s|_.*||g" )
    fi
    [[ -z "${BRAND}" ]] && BRAND=$(echo $FINGERPRINT | cut -d / -f1 )
    if grep -q "ro.oppo.market.name" "$CAT_FILE"; then
        MODEL=$( cat "$CAT_FILE" | grep "ro.oppo.market.name=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.display.series" "$CAT_FILE"; then
        MODEL=$( cat "$CAT_FILE" | grep "ro.display.series=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.product.display" "$CAT_FILE"; then
        MODEL=$( cat "$CAT_FILE" | grep "ro.product.display=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.semc.product.name" "$CAT_FILE"; then
        MODEL=$( cat "$CAT_FILE" | grep "ro.semc.product.name=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.product.odm.model" "$CAT_FILE"; then
        MODEL=$( cat "$CAT_FILE" | grep "ro.product.odm.model=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.product.vendor.model" "$CAT_FILE"; then
        MODEL=$( cat "$CAT_FILE" | grep "ro.product.vendor.model=" | sed "s|.*=||g" | head -n 1 )
    else
        MODEL=$( cat "$CAT_FILE" | grep "ro.product" | grep "model=" | sed "s|.*=||g" | head -n 1 )
    fi
    [[ -z "$MODEL" ]] && MODEL=$DEVICE
    PLATFORM=$( cat "$CAT_FILE" | grep "ro.board.platform" | sed "s|.*=||g" | head -n 1 )
    SECURITY_PATCH=$( cat "$CAT_FILE" | grep "build.version.security_patch=" | sed "s|.*=||g" | head -n 1 )

    # Date
    if grep -q "ro.system.build.date=" "$CAT_FILE"; then
        DATE=$( cat "$CAT_FILE" | grep "ro.system.build.date=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.vendor.build.date=" "$CAT_FILE"; then
        DATE=$( cat "$CAT_FILE" | grep "ro.vendor.build.date=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.build.date=" "$CAT_FILE"; then
        DATE=$( cat "$CAT_FILE" | grep "ro.build.date=" | sed "s|.*=||g" | head -n 1 )
    elif grep -q "ro.bootimage.build.date=" "$CAT_FILE"; then
        DATE=$( cat "$CAT_FILE" | grep "ro.bootimage.build.date=" | sed "s|.*=||g" | head -n 1 )
    fi

    BRANCH=$(echo $DESCRIPTION $DATE | tr ' ' '-' | tr ':' '-')
    TOPIC1=$(echo $BRAND | tr '[:upper:]' '[:lower:]' | tr -dc '[[:print:]]' | tr '_' '-' | cut -c 1-35)
    TOPIC2=$(echo $PLATFORM | tr '[:upper:]' '[:lower:]' | tr -dc '[[:print:]]' | tr '_' '-' | cut -c 1-35)
    TOPIC3=$(echo $DEVICE | tr '[:upper:]' '[:lower:]' | tr -dc '[[:print:]]' | tr '_' '-' | cut -c 1-35)

    # Display var's
    declare -a arr=("BRAND" "DEVICE" "DESCRIPTION" "FINGERPRINT" "MODEL" "PLATFORM" "SECURITY_PATCH" "VERSION" "DATE" "FLAVOR" "ID" "INCREMENTAL" "TAGS" "BRANCH")
    for i in "${arr[@]}"; do printf "$i: ${!i}\n"; done
    # Cleanup
    rm -rf $PROJECT_DIR/working/system_build* $PROJECT_DIR/working/*prop $PROJECT_DIR/working/all_files.txt
done

vendor_dir_name="vendor_$BRAND""_""$DEVICE"

apache_license () {
echo "                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!)  The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [yyyy] [name of copyright owner]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License." | tee LICENSE
git add .
git commit -s -m "$DEVICE: APACHE 2.0 LICENSE"
echo "Apache Licence Added to Vendor and Commited to GIT"
}

vendor_template () {
echo "#
# Copyright (C) 2021 The Android Open-Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# This file is generated by device/$BRAND/$DEVICE/setup-makefiles.sh
" | tee "$DEVICE-vendor.mk" "BoardConfigVendor.mk" "Android.mk"


echo "LOCAL_PATH := \$(call my-dir)

ifeq (\$(TARGET_DEVICE),$DEVICE)

endif
" | tee -a Android.mk

echo "//
// Copyright (C) 2021 The Android Open-Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This file is generated by device/$BRAND/$DEVICE/setup-makefiles.sh
" | tee Android.bp
git lfs track "*.apk"
git add .
git commit -s -m "$DEVICE: vendor-tree template"

echo "PRODUCT_SOONG_NAMESPACES += \\
    vendor/$BRAND/$DEVICE
" | tee -a $DEVICE-vendor.mk

echo "soong_namespace {
}
" | tee -a Android.bp

git add .
git commit -s -m "$DEVICE: define soong namespace"
echo "Created Vendor_Tree Template"

}

split_extraction () {
if ls $(pwd)/working 1> /dev/null 2>&1; then
	rm -rf working && mkdir working
	./tools/proprietary-files.sh $dump_path
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
	./tools/vendor_tree.sh $dump_path
	cp -R vendor/$BRAND/$DEVICE/proprietary $vendor_dir_name/proprietary
	echo "" >> vendor/$BRAND/$DEVICE/$DEVICE-vendor.mk
	echo "# $blobs_name"| tee -a $vendor_dir_name/$DEVICE-vendor.mk
	tail -n +4 vendor/$BRAND/$DEVICE/$DEVICE-vendor.mk |tail +1 | tee -a $vendor_dir_name/$DEVICE-vendor.mk
	tail -n +4 vendor/$BRAND/$DEVICE/Android.bp | tee -a $vendor_dir_name/Android.bp
	cd $vendor_dir_name && git add . && git commit -s -m "$DEVICE: $blobs_name blobs from stock" && cd -
done < "$filename"

rm -rf $(pwd)/working/proprietary-files.txt
mv $(pwd)/working/backup_proprietary-files.txt $(pwd)/working/proprietary-files.txt
}

vendor_dir (){
	mkdir $vendor_dir_name
	echo "$vendor_dir_name created."
	cd $vendor_dir_name
	git init
	apache_license
	vendor_template
	cd ..
	split_extraction
}

if ls $vendor_dir_name 1> /dev/null 2>&1; then
	echo "$vendor_dir_name Already Present"
	rm -rf $(pwd)/$vendor_dir_name
	vendor_dir
else
	vendor_dir
fi

clear
echo "VENDOR is Extracted : $(pwd)/$vendor_dir_name/"
