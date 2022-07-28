#!/bin/sh

# verbose and exit on error
set -xe

# import GPG keys
gpg --import /gpg/nextcloud-bot.public.asc
gpg --allow-secret-key-import --import /gpg/nextcloud-bot.asc
gpg --list-keys

# fetch git repo
git clone git@github.com:$1/$2 /app

versions="master $(git branch -r | grep -E "origin\/stable\-[0-9\.]+$" | cut -f2 -d"/")"

# remove existing translations to cleanup not maintained languages
# default Android app
if [ -d src/main/res ]; then
  rm -rf src/main/res/values-*/strings.xml
fi
# Android news app
if [ -d News-Android-App/src/main/res ]; then
  rm -rf News-Android-App/src/main/res/values-*/strings.xml
fi
# Android talk app
if [ -d app/src/main/res ]; then
  rm -rf app/src/main/res/values-*/strings.xml
fi

# combine stable branches to keep freshly removed translations
if [ $1 = "nextcloud" -a $2 = "android" ]; then
  mkdir stable-values
  for version in $versions
  do
    git checkout $version
    cp app/src/main/res/values/strings.xml stable-values/$version.xml
  done

  cd stable-values
  echo '<?xml version="1.0" encoding="utf-8"?>
  <resources>' >> combined.xml

  grep -h "<string" *.xml | sort -u | sed s'#\t#    #'g >> combined.xml

  # plurals are hard to compare, so we take only master ones
  awk '/<plurals/,/<\/plurals>/' master.xml >> combined.xml

  echo "</resources>" >> combined.xml

  cat combined.xml

  mv combined.xml ../app/src/main/res/values/strings.xml

  cd ..

  rm -rf stable-values
fi

if [ $1 = "nextcloud" -a $2 = "talk-android" ]; then
  mkdir stable-values
  for version in $versions
  do
    git checkout $version
    cp app/src/main/res/values/strings.xml stable-values/$version.xml
  done

  cd stable-values
  echo '<?xml version="1.0" encoding="utf-8"?>
  <resources>' >> combined.xml

  grep -h "<string" *.xml | sort -u | sed s'#\t#    #'g >> combined.xml

  # plurals are hard to compare, so we take only master ones
  awk '/<plurals/,/<\/plurals>/' master.xml >> combined.xml

  echo "</resources>" >> combined.xml

  cat combined.xml

  mv combined.xml ../app/src/main/res/values/strings.xml

  cd ..

  rm -rf stable-values
fi

# push sources
tx push -s

# undo local changes
if [ $1 = "nextcloud" -a $2 = "android" ]; then
  git checkout -- app/src/main/res/values/strings.xml
  git checkout master
fi

if [ $1 = "nextcloud" -a $2 = "talk-android" ]; then
  git checkout -- app/src/main/res/values/strings.xml
  git checkout master
fi

for version in $versions
do

  # skip if the branch doesn't exist
  if git branch -r | egrep "^\W*origin/$version$" ; then
    echo "Valid branch"
  else
    echo "Invalid branch"
    continue
  fi

  if [ $1 = "nextcloud" -a $2 = "talk-android" ]; then
    git checkout -b branch-$version $version
  else
  	git checkout $version
  fi

  # pull translations
  tx pull -f -a --minimum-perc=50

  # for the default Android app rename the informal german to the formal version
  if [ -d src/main/res ]; then
    rm -rf src/main/res/values-de
    mv src/main/res/values-de-rDE src/main/res/values-de

    # reset combined source file
    git checkout -- src/main/res/values/strings.xml
  fi
  # for the Android talk and files app rename the informal german to the formal version
  if [ -d app/src/main/res ]; then
    rm -rf app/src/main/res/values-de
    mv app/src/main/res/values-de-rDE app/src/main/res/values-de
  fi
  # for the Android news app rename the informal german to the formal version
  if [ -d News-Android-App/src/main/res ]; then
    rm -rf News-Android-App/src/main/res/values-de
    mv News-Android-App/src/main/res/values-de-rDE News-Android-App/src/main/res/values-de
  fi

  if [ -e "scripts/metadata/generate_metadata.py" ]; then
    # copy transifex strings to fastlane
    python3 scripts/metadata/generate_metadata.py
  fi

  # create git commit and push it
  if [ $1 = "nextcloud" -a $2 = "talk-android" ]; then
  	git add .
	git commit -am "[tx-robot] updated from transifex" -s || true
  	gh pr create -t "[tx-robot] updated from transifex" --base $version --body ""
  else
	git add .
	git commit -am "[tx-robot] updated from transifex" -s || true
	git push origin $version
	echo "done"
  fi
done
