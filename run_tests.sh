#! /bin/sh

cd tests

export QUIET_TEST=1
export HUGETLB_VERBOSE=2
unset HUGETLB_ELF
unset HUGETLB_MORECORE

ENV=/usr/bin/env

run_test_bits () {
    BITS=$1
    shift

    if [ -d obj$BITS ]; then
	echo -n "$@ ($BITS):	"
	PATH="obj$BITS" LD_LIBRARY_PATH="../obj$BITS" $ENV "$@"
    fi
}

run_test () {
    for bits in 32 64; do
	run_test_bits $bits "$@"
    done
}

preload_test () {
    run_test LD_PRELOAD=libhugetlbfs.so "$@"
}

elflink_test () {
    args=("$@")
    N="$[$#-1]"
    baseprog="${args[$N]}"
    unset args[$N]
    set -- "${args[@]}"
    run_test "$@" "$baseprog"
    # Test we don't blow up if not linked for hugepage
    preload_test "$@" "$baseprog"
    run_test "$@" "xB.$baseprog"
    run_test "$@" "xBDT.$baseprog"
}

functional_tests () {
    #run_test dummy
# Kernel background tests not requiring hugepage support
    run_test zero_filesize_segment

# Library background tests not requiring hugepage support
    run_test test_root
    run_test meminfo_nohuge

# Library tests requiring kernel hugepage support
    run_test gethugepagesize
    run_test empty_mounts

# Tests requiring an active and usable hugepage mount
    run_test find_path
    run_test unlinked_fd
    run_test readback
    run_test truncate
    run_test shared

# Specific kernel bug tests
    run_test ptrace-write-hugepage
    run_test icache-hygeine
    run_test slbpacaflush
    run_test_bits 64 straddle_4GB
    run_test_bits 64 huge_at_4GB_normal_below
    run_test_bits 64 huge_below_4GB_normal_above

# Tests requiring an active mount and hugepage COW
    run_test private
    run_test malloc
    preload_test HUGETLB_MORECORE=yes malloc
    run_test malloc_manysmall
    preload_test HUGETLB_MORECORE=yes malloc_manysmall
    elflink_test HUGETLB_VERBOSE=0 linkhuge_nofd # Lib error msgs expected
    elflink_test linkhuge
}

stress_tests () {
    ITERATIONS=10           # Number of iterations for looping tests
    THREADS=10              # Number of threads for multi-threaded tests
    NRPAGES=16
    DEVICE=/dev/full

    run_test mmap-gettest ${ITERATIONS} ${NRPAGES}
    run_test mmap-cow ${THREADS} ${NRPAGES}
    run_test shm-gettest ${ITERATIONS} ${NRPAGES}
    run_test shm-fork ${THREADS} ${NRPAGES}
    run_test shm-getraw ${NRPAGES} ${DEVICE}
}

while getopts "vVdt:" ARG ; do
    case $ARG in
	"v")
	    unset QUIET_TEST=1
	    ;;
	"V")
	    HUGETLB_VERBOSE=99
	    ;;
	"t")
	    TESTSETS=$OPTARG
	    ;;
    esac
done

if [ -z "$TESTSETS" ]; then
    TESTSETS="func stress"
fi

for set in $TESTSETS; do
    case $set in
	"func")
	    functional_tests
	    ;;
	"stress")
	    stress_tests
	    ;;
    esac
done
