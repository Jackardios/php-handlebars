{
  lib,
  php,
  stdenv,
  autoreconfHook,
  fetchurl,
  pkg-config,
  talloc,
  pcre,
  pcre2,
  buildPecl,
  handlebarsc,
  lcov ? null,
  valgrind ? null,
  php_psr ? null,
  handlebars_spec ? null,
  mustache_spec ? null,
  astSupport ? false,
  checkSupport ? true,
  debugSupport ? false,
  devSupport ? false,
  hardeningSupport ? true,
  psrSupport ? true,
  WerrorSupport ? (debugSupport || devSupport),
  valgrindSupport ? (debugSupport || devSupport),
  coverageSupport ? false,
  src,
}:
(buildPecl rec {
  pname = "handlebars";
  name = "handlebars-${version}";
  version = "v1.0.0";

  inherit src;

  passthru = {
    inherit stdenv php;
  };

  outputs =
    lib.optional (checkSupport && coverageSupport) "coverage"
    ++ ["out" "dev"];

  buildInputs =
    [handlebarsc talloc pcre pcre2]
    ++ lib.optional valgrindSupport valgrind
    ++ lib.optional psrSupport php_psr;

  nativeBuildInputs =
    [php.unwrapped.dev pkg-config]
    ++ lib.optionals checkSupport [handlebars_spec]
    ++ lib.optional valgrindSupport valgrind
    ++ lib.optional coverageSupport lcov;

  configureFlags =
    []
    ++ lib.optional astSupport "--enable-handlebars-ast"
    ++ lib.optional (!astSupport) "--disable-handlebars-ast"
    ++ lib.optional hardeningSupport "--enable-handlebars-hardening"
    ++ lib.optional (!hardeningSupport) "--disable-handlebars-hardening"
    ++ lib.optional psrSupport "--enable-handlebars-psr"
    ++ lib.optional (!psrSupport) "--disable-handlebars-psr"
    ++ lib.optional WerrorSupport "--enable-compile-warnings=error"
    ++ lib.optionals (!WerrorSupport) ["--enable-compile-warnings=yes" "--disable-Werror"]
    ++ lib.optional coverageSupport ["--enable-handlebars-coverage"];

  makeFlags = ["phpincludedir=$(dev)/include"];

  preBuild =
    # (lib.optionalString checkSupport ''
    #   HANDLEBARS_SPEC_DIR="${handlebars_spec}/share/handlebars-spec" \
    #       MUSTACHE_SPEC_DIR="${mustache_spec}" \
    #       ${php}/bin/php generate-tests.php
    # '')
    # +
    lib.optionalString coverageSupport ''
      lcov --directory . --zerocounters
      lcov --directory . --capture --compat-libtool --initial --output-file coverage.info
    '';

  doCheck = checkSupport;

  theRealFuckingCheckPhase =
    ''
      runHook preCheck
      REPORT_EXIT_STATUS=1 NO_INTERACTION=1 make test TEST_PHP_ARGS="-n" || (find tests -name '*.log' | xargs cat ; exit 1)
    ''
    + (lib.optionalString valgrindSupport ''
      USE_ZEND_ALLOC=0 REPORT_EXIT_STATUS=1 NO_INTERACTION=1 make test TEST_PHP_ARGS="-n -m" || (find tests -name '*.mem' | xargs cat ; exit 1)
    '')
    + ''
      runHook postCheck
    '';

  postCheck = lib.optionalString coverageSupport ''
    lcov --no-checksum --directory . --capture --no-markers --compat-libtool --output-file coverage.info
    set -o noglob
    lcov --remove coverage.info '${builtins.storeDir}/*' \
        --compat-libtool \
        --output-file coverage.info
    set +o noglob
    mkdir -p $coverage
    cp coverage.info $coverage/coverage.info
    genhtml coverage.info -o $coverage/html/
  '';

  meta = with lib; {
    homepage = "https://github.com/jbboehr/php-handlebars";
    license = licenses.bsd2;
    outputsToInstall = outputs;
  };
})
.overrideAttrs (o:
    o
    // {
      checkPhase = o.theRealFuckingCheckPhase;
    })
