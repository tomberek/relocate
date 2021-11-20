{ runCommand, nix, lib , nixrewrite }:

# Replace the prefix of the requisites tree of drv, propagating
# the change all the way up the tree, without a full rebuild.
# Example: safeFirefox = replaceDependency {
#   drv = firefox;
# };
{ drv, verbose ? true, storePrefix ? "/tmp/store" }:

with lib;

let
  origDrv = drv;
  warn = if verbose then builtins.trace else (x: y: y);
  references = import (runCommand "references.nix" { exportReferencesGraph = [ "graph" drv ]; } ''
    (echo {
    while read path
    do
        echo "  \"$path\" = ["
        read count
        read count
        while [ "0" != "$count" ]
        do
            read ref_path
            if [ "$ref_path" != "$path" ]
            then
                echo "    (\"$ref_path\")"
            fi
            count=$(($count - 1))
        done
        echo "  ];"
    done < graph
    echo }) > $out
  '').outPath;

  discard = builtins.unsafeDiscardStringContext;

  referencesOf = drv: references.${discard (toString drv)};

  drvName = drv:
    discard (substring 33 (stringLength (builtins.baseNameOf drv)) (builtins.baseNameOf drv));

    rewriteHashes = drv: hashes: runCommand (drvName drv) {
      nixStore = "${nix.out}/bin/nix-store";
      buildInputs = [ nixrewrite origDrv ];
      } ''
    echo "${(builtins.concatStringsSep "\n" (builtins.attrValues hashes))}" > deps
    echo ${drv} >> deps
    for i in $outputs ; do
        echo ''${!i} >> deps
    done

    cat deps | sort | uniq | xargs -L1 basename > hash.list
    cat hash.list

    $nixStore --dump ${drv} | sed 's|${baseNameOf drv}|'$(basename $out)'|g' ${
      lib.optionalString (builtins.length (builtins.attrNames hashes) != 0)
        "| sed -e ${concatStringsSep " -e " (mapAttrsToList (name: value:
            "'s|${baseNameOf name}|${baseNameOf value}|g'"
      ) hashes)
    }"} | nixrewrite /nix/store ${storePrefix} hash.list | $nixStore --restore $out
  '';

  rewriteMemo = listToAttrs (map
    (drv: { name = discard (toString drv);
            value = rewriteHashes (drv)
              (filterAttrs (n: v: builtins.elem ((discard (toString n))) (referencesOf drv)) rewriteMemo);
          })
    (builtins.attrNames references)) ;

  drvHash = discard (toString drv);

in
rewriteMemo.${drvHash}
