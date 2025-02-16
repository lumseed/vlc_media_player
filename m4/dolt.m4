dnl dolt, a replacement for libtool
dnl Copyright © 2007-2010 Josh Triplett <josh@joshtriplett.org>
dnl Copying and distribution of this file, with or without modification,
dnl are permitted in any medium without royalty provided the copyright
dnl notice and this notice are preserved.
dnl
dnl To use dolt, invoke the DOLT macro immediately after the libtool macros.
dnl Optionally, copy this file into acinclude.m4, to avoid the need to have it
dnl installed when running autoconf on your project.

AC_DEFUN([DOLT], [
AC_REQUIRE([AC_CANONICAL_HOST])
# dolt, a replacement for libtool
# Josh Triplett <josh@freedesktop.org>
AC_PATH_PROG([DOLT_BASH], [bash])
AC_MSG_CHECKING([if dolt supports this host])
dolt_supported=yes
AS_IF([test x$DOLT_BASH = x], [dolt_supported=no])
AS_IF([test x$GCC != xyes], [dolt_supported=no])

AS_CASE([$host],
    [*-*-linux*|*-*-freebsd*], [pic_options='-fPIC'],
    [*-apple-darwin*],         [pic_options='-fno-common'],
    [*mingw*],                 [pic_options='']
    [*],                       [dolt_supported=no]
)
AS_IF([test x$dolt_supported = xno], [
    AC_MSG_RESULT([no, falling back to libtool])
    LTCOMPILE='$(LIBTOOL) $(AM_V_lt) --tag=CC $(AM_LIBTOOLFLAGS) $(LIBTOOLFLAGS) --mode=compile $(COMPILE)'
    LTCXXCOMPILE='$(LIBTOOL) $(AM_V_lt) --tag=CXX $(AM_LIBTOOLFLAGS) $(LIBTOOLFLAGS) --mode=compile $(CXXCOMPILE)'
    m4_pattern_allow([AM_V_lt])
], [
    AC_MSG_RESULT([yes, replacing libtool])

dnl Start writing out doltcompile.
    cat <<__DOLTCOMPILE__EOF__ >doltcompile
#!$DOLT_BASH
__DOLTCOMPILE__EOF__
    cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
args=("$[]@")
for ((arg=0; arg<${#args@<:@@@:>@}; arg++)) ; do
    if test x"${args@<:@$arg@:>@}" = x-o ; then
        objarg=$((arg+1))
        break
    fi
done
if test x$objarg = x ; then
    echo 'Error: no -o on compiler command line' 1>&2
    exit 1
fi
lo="${args@<:@$objarg@:>@}"
obj="${lo%.lo}"
if test x"$lo" = x"$obj" ; then
    echo "Error: libtool object file name \"$lo\" does not end in .lo" 1>&2
    exit 1
fi
objbase="${obj##*/}"
__DOLTCOMPILE__EOF__

dnl Write out shared compilation code.
    if test x$enable_shared = xyes; then
        cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
libobjdir="${obj%$objbase}.libs"
if test ! -d "$libobjdir" ; then
    mkdir_out="$(mkdir "$libobjdir" 2>&1)"
    mkdir_ret=$?
    if test "$mkdir_ret" -ne 0 && test ! -d "$libobjdir" ; then
	echo "$mkdir_out" 1>&2
        exit $mkdir_ret
    fi
fi
pic_object="$libobjdir/$objbase.o"
args@<:@$objarg@:>@="$pic_object"
__DOLTCOMPILE__EOF__
    cat <<__DOLTCOMPILE__EOF__ >>doltcompile
    pic_options="$pic_options"
    if test x\$passthrough = xtrue; then
        pic_options=""
    fi
__DOLTCOMPILE__EOF__
    cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
${args@<:@@@:>@} $pic_options -DPIC || exit $?
__DOLTCOMPILE__EOF__
    fi

dnl Write out static compilation code.
dnl Avoid duplicate compiler output if also building shared objects.
    if test x$enable_static = xyes; then
        cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
non_pic_object="$obj.o"
args@<:@$objarg@:>@="$non_pic_object"
__DOLTCOMPILE__EOF__
        if test x$enable_shared = xyes; then
            cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
"${args@<:@@@:>@}" >/dev/null 2>&1 || exit $?
__DOLTCOMPILE__EOF__
        else
            cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
"${args@<:@@@:>@}" || exit $?
__DOLTCOMPILE__EOF__
        fi
    fi

dnl Write out the code to write the .lo file.
dnl The second line of the .lo file must match "^# Generated by .*libtool"
    cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
{
echo "# $lo - a libtool object file"
echo "# Generated by doltcompile, not libtool"
__DOLTCOMPILE__EOF__

    if test x$enable_shared = xyes; then
        cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
echo "pic_object='.libs/${objbase}.o'"
__DOLTCOMPILE__EOF__
    else
        cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
echo pic_object=none
__DOLTCOMPILE__EOF__
    fi

    if test x$enable_static = xyes; then
        cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
echo "non_pic_object='${objbase}.o'"
__DOLTCOMPILE__EOF__
    else
        cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
echo non_pic_object=none
__DOLTCOMPILE__EOF__
    fi

    cat <<'__DOLTCOMPILE__EOF__' >>doltcompile
} > "$lo"
__DOLTCOMPILE__EOF__

dnl Done writing out doltcompile; substitute it for libtool compilation.
    chmod +x doltcompile
    LTCOMPILE='$(top_builddir)/doltcompile $(COMPILE)'
    LTCXXCOMPILE='$(top_builddir)/doltcompile $(CXXCOMPILE)'

dnl automake ignores LTCOMPILE and LTCXXCOMPILE when it has separate CFLAGS for
dnl a target, so write out a libtool wrapper to handle that case.
dnl Note that doltlibtool does not handle inferred tags or option arguments
dnl without '=', because automake does not use them.
    cat <<__DOLTLIBTOOL__EOF__ > doltlibtool
#!$DOLT_BASH
__DOLTLIBTOOL__EOF__
    cat <<'__DOLTLIBTOOL__EOF__' >>doltlibtool
top_builddir_slash="${0%%doltlibtool}"
: ${top_builddir_slash:=./}
args=()
modeok=false
tagok=false
for arg in "$[]@"; do
    case "$arg" in
        --mode=compile) modeok=true ;;
        --tag=CC|--tag=CXX) tagok=true ;;
        --tag=ASM|--tag=YASM) tagok=true; passthrough=true;;
        --silent|--quiet) ;;
        *) args@<:@${#args[@]}@:>@="$arg" ;;
    esac
done
if $modeok && $tagok ; then
    . ${top_builddir_slash}doltcompile "${args@<:@@@:>@}"
else
    exec ${top_builddir_slash}libtool "$[]@"
fi
__DOLTLIBTOOL__EOF__

dnl Done writing out doltlibtool; substitute it for libtool.
    chmod +x doltlibtool
    LIBTOOL='$(top_builddir)/doltlibtool'

DOLT_CLEANFILES="doltlibtool doltcompile"
AC_SUBST(DOLT_CLEANFILES)
])
AC_SUBST(LTCOMPILE)
AC_SUBST(LTCXXCOMPILE)
# end dolt
])
