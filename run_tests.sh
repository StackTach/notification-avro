#!/bin/bash

function usage {
  echo "Usage: $0 [OPTION]..."
  echo "Run QonoS' test suite(s)"
  echo ""
  echo "  -V, --virtual-env        Always use virtualenv.  Install automatically if not present"
  echo "  -N, --no-virtual-env     Don't use virtualenv.  Run tests in local environment"
  echo "  -f, --force              Force a clean re-build of the virtual environment. Useful when dependencies have been added."
  echo "  -h, --help               Print this usage message"
  echo ""
  echo "Note: with no options specified, the script will try to run the tests in a virtual environment,"
  echo "      If no virtualenv is found, the script will ask if you would like to create one.  If you "
  echo "      prefer to run tests NOT in a virtual environment, simply pass the -N option."
  exit
}

function process_option {
  case "$1" in
    -h|--help) usage;;
    -V|--virtual-env) let always_venv=1; let never_venv=0;;
    -N|--no-virtual-env) let always_venv=0; let never_venv=1;;
    -f|--force) let force=1;;
  esac
}

venv=.venv
with_venv=tools/with_venv.sh
always_venv=0
never_venv=0
force=0
wrapper=""
tools_path="lib"
idl_path="avdl"
schema_path="avsc"
avro_tools="avro-tools-1.7.7.jar"
avro_mirror="http://www.gtlib.gatech.edu/pub/apache/avro/avro-1.7.7/java/"

for arg in "$@"; do
  process_option $arg
done

function run_tests {
  generate_schemas
}

function generate_schemas {
  download_avro
  # Clean out existing schemas
  if [ -d "${schema_path}" ]; then
    rm -Rf "${schema_path}"
  fi
  mkdir "${schema_path}"

  for file in ${idl_path}/*.avdl ; do
    if [[ ! -d "$file" ]]; then
      echo -n "Processing IDL: $file ... "
      java -jar "${tools_path}/${avro_tools}" idl2schemata "${file}" "${schema_path}"; RC=$?
      if [ "$RC" != "0" ]; then
          echo "Fail"
          FAILURES=$((FAILURES + 1))
      else
          echo "Done"
      fi
    fi
  done
}

# Download the avro tools jar file if needed
function download_avro {
  if [ ! -d "${tools_path}" ]; then
    mkdir lib
  fi
  if [ ! -e "${tools_path}/${avro_tools}" ]; then
    echo "Downloading ${avro_tools}"
    pushd "${tools_path}"
    wget "${avro_mirror}${avro_tools}"
    popd
  else
    echo "Found ${tools_path} - skipping download"
  fi
}

if [ $never_venv -eq 0 ]
then
  # Remove the virtual environment if --force used
  if [ $force -eq 1 ]; then
    echo "Cleaning virtualenv..."
    rm -rf ${venv}
  fi
  if [ -e ${venv} ]; then
    wrapper="${with_venv}"
  else
    if [ $always_venv -eq 1 ]; then
      # Automatically install the virtualenv
      python tools/install_venv.py
      wrapper="${with_venv}"
    else
      echo -e "No virtual environment found...create one? (Y/n) \c"
      read use_ve
      if [ "x$use_ve" = "xY" -o "x$use_ve" = "x" -o "x$use_ve" = "xy" ]; then
        # Install the virtualenv and run the test suite in it
        python tools/install_venv.py
	wrapper=${with_venv}
      fi
    fi
  fi
fi

run_tests || exit
