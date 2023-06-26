xquery version "3.1";

(:~  
: Ce module permet de créer un fichier de configuration d'un projet / d'une collection. Ce document sert ensuite pour le routeur dots. Spécifiquement, le rôle de ce module est de créer le document de configuration, en y intégrant toutes les collections et ressources, avec leurs métadonnées OBLIGATOIRES (title, id, type, totalItems etc.)
: @author   Philippe Pons
: @since 2023-05-25
: @version  1.0
: @todo Mise à jour du fichier de configuration?
: @todo Compléter ce code en ajoutant la création ou la MAJ de la base de données "config" (/!\ comment se passer de cette étape?)
:)

module namespace cc = "https://github.com/chartes/dots/schema/utils/cc";

import module namespace ccg = "https://github.com/chartes/dots/schema/utils/ccg" at "root.xqm";
import module namespace cc2 = "https://github.com/chartes/dots/schema/utils/cc2" at "project_metadata.xqm";

declare namespace dots = "https://github.com/chartes/dots/";
declare namespace dc = "http://purl.org/dc/elements/1.1/";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $cc:config := "config.xml";
declare variable $cc:declaration := "declaration.xml";
declare variable $cc:metadata := "metadata";

(:~  
: Cette fonction permet de construire un document XML de configuration (servant ensuite au routeur DoTS) à ajouter à la base de données XML.
: @return document XML
: @param $path chaîne de caractères. Pour lancer cette fonction, la valeur de ce paramètre est vide ("") (cet argument est nécessaire pour d'autres fonctions appelés par cc:create_config)
: @param $counter nombre entier. Par défaut, ce nombre est de 0. Il est ensuite utilisé pour définir la valeur d'attribut @level d'un <member/> (cet argument est nécessaire pour d'autres fonctions appelés par cc:create_config).
: @see create_config.xql;cc:getMetadata
: @see create_config.xql;cc:members
:)
declare updating function cc:create_config($bdd as xs:string, $title as xs:string, $path as xs:string, $counter as xs:integer, $boolean) {
  let $countChild := 
    let $countConfig := if (db:get($bdd, $cc:config)) then 1 else 0
    let $countDeclaration := if (db:get($bdd, $cc:declaration)) then 1 else 0
    let $countMetadata := 
      if (db:get($bdd, $cc:metadata)) then 1 else 0
    let $countOtherContent := sum( ($countConfig, $countDeclaration, $countMetadata) )
    let $count := count(db:dir($bdd, ""))
    return
      $count - $countOtherContent
  let $content :=
    <dots:configuration
      xmlns:dots="https://github.com/chartes/dots/"
      xmlns:dct="http://purl.org/dc/terms/"
      xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns:html="http://www.w3.org/1999/xhtml"
      xmlns:tei="http://www.tei-c.org/ns/1.0"
    >
      {cc:getMetadata($bdd)},
      <dots:configContent>
        <dots:members>
          <dots:member xml:id="{$bdd}" level="1" type="collection" n="{$countChild}">
            <dc:title>{$title}</dc:title>
          </dots:member>
          {cc:members($bdd, $path, $counter, $boolean)}</dots:members>
        </dots:configContent>
    </dots:configuration>
  return
    (
      ccg:create_config($bdd),
      if (db:exists($bdd, "config.xml"))
      then 
        let $config := db:get($bdd, "config.xml")
        return
        (
          replace value of node $config//dots:lastUpdate with current-dateTime(),
          replace node $config//dots:configContent with $content//dots:configContent
        )
      else 
        (
          db:add($bdd, $content, "config.xml")
        )
    )
};

(:~ 
: Cette fonction se contente de construire l'en-tête <dots:configMetadata/> du fichier de configuration
:)
declare function cc:getMetadata($bdd as xs:string) {
  <dots:configMetadata>
    <dots:gitVersion/><!-- version git du fichier -->
    <dots:creationDate>{current-dateTime()}</dots:creationDate><!-- date de création du document -->
    <dots:lastUpdate>{current-dateTime()}</dots:lastUpdate><!-- date de la dernière mise à jour -->
    <dots:publisher>École nationale des chartes</dots:publisher>
    <dots:description>Bibliothèque de resources DoTS du projet {$bdd}</dots:description>
    <dots:licence>https://opensource.org/license/mit/</dots:licence>
  </dots:configMetadata>
};

(:~ 
: Cette fonction récursive permet de recenser les collections et les resources d'une base de données XML 
: et de renvoyer vers les fonctions idoines pour construire le contenu du fichier de configuration.
: @param $path chaîne de caractères. Pour lancer cette fonction, la valeur de ce paramètre est vide ("")
: @param $counter nombre entier. Par défaut, ce nombre est de 0. Il est ensuite utilisé pour définir la valeur d'attribut @level d'un <member/>
: @see create_config.xql;cc:collection
: @see create_config.xql;cc:resource
:)
declare function cc:members($bdd as xs:string, $path as xs:string, $counter as xs:integer, $boolean) {
  for $dir in db:dir($bdd, $path)
  where not(contains($dir, "metadata"))
  order by $dir
  return
    if (contains($dir, ".xml"))
    then cc:resource($bdd, $dir, $path, $boolean)
    else
      (
        cc:collection($bdd, $dir, $path, $counter),
        cc:members($bdd, $dir, $counter + 1, $boolean)
      )
};

(:~ 
: Cette fonction permet de construire l'élément <member/> correspondant à une resource, avec les métadonnées obligatoires: @id, @type, title, totalItems (à compléter probablement)
: @param $path chaîne de caractères.
: @param $counter nombre entier. Il est utilisé pour définir la valeur d'attribut @level d'un <member/>
:)
declare function cc:resource($bdd as xs:string, $resource as xs:string, $path as xs:string, $boolean) {
  let $doc := db:get($bdd, concat($path, "/", $resource))/tei:TEI
  let $id := normalize-space($doc/@xml:id)
  let $title := normalize-space($doc//tei:titleStmt/tei:title[1])
  let $content := 
    cc2:getContent($bdd, $id) 
  return
    if ($doc)
    then
      <dots:member xml:id="{$id}" target="#{if ($path) then $path else $bdd}" type="resource">
        <dc:title>{$title}</dc:title>
        {$content}
      </dots:member>
    else ()
};

(:~ 
: Cette fonction permet de construire l'élément <member/> correspondant à une collection, avec les métadonnées obligatoires: @id, @type, title, totalItems (à compléter probablement)
: @param $path chaîne de caractères.
: @param $counter nombre entier. Il est utilisé pour définir la valeur d'attribut @level d'un <member/>
:)
declare function cc:collection($bdd as xs:string, $collection as xs:string, $path as xs:string, $counter as xs:integer) {
  let $totalItems := count(db:dir($bdd, $collection))
  let $parent := if ($path = "") then $bdd else $path
  let $title := db:open($bdd, "declaration.xml")//dots:titles/dots:title[@xml:id=$collection]
  return
    <dots:member xml:id="{$collection}" type="collection" target="#{$parent}" level="{$counter + 2}" n="{$totalItems}">
      <dc:title>{if ($title) then normalize-space($title) else ()}</dc:title>
    </dots:member>
};






