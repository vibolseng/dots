xquery version "3.1";

(:~  
: Ce module permet à un utilisateur de DoTS de supprimer les registres DoTS du projet de son choix
: @author École nationale des chartes - Philippe Pons
: @since 2023-10-12
: @version  1.0
:)

module namespace dbd = "https://github.com/chartes/dots/db/dbd";

import module namespace G = "https://github.com/chartes/dots/globals" at "../globals.xqm";

declare default element namespace "https://github.com/chartes/dots/";
declare namespace dct = "http://purl.org/dc/terms/";

declare variable $dbd:dbName := "theatre";

declare updating function dbd:handleDelete() {
  dbd:dbSwitchDelete(),
  dbd:registersDelete()
};

declare updating function dbd:dbSwitchDelete() {
  let $dbDots := db:get($G:dots)/dbSwitch
  let $totalProjects := $dbDots//totalProjects
  let $modified := $dbDots//dct:modified
  let $member := $dbDots//member
  return
    (
      replace value of node $modified with current-dateTime(),
      replace value of node $totalProjects with xs:integer($totalProjects) - 1,
      for $member in $member/node()[@dbName = $dbd:dbName]
      return
        delete node $member
    )
};

declare updating function dbd:registersDelete() {
  db:delete($dbd:dbName, $G:resourcesRegister),
  db:delete($dbd:dbName, $G:fragmentsRegister)
  
};