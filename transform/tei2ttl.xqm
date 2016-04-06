xquery version "3.0";
(:
 : Build ttl output for Gazetteer data. 
 : Based on examples: https://github.com/srophe/Linked-Data/blob/master/ShortEdessaPlace78inPGIF.ttl 
:)

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare option exist:serialize "method=text media-type=text/turtle indent=yes";

declare variable $id {request:get-parameter('id', '')};

(: Create URI :)
declare function local:make-uri($uri){
    concat('<',normalize-space($uri),'>')
};

(: Add language :)
declare function local:make-lang($lang) as xs:string?{
    concat('@',$lang)
};

(: Build literal string, add lang if specified :)
declare function local:make-literal($string, $lang) as xs:string?{
    concat('"',normalize-space(string-join($string,' ')),'"',
        if($lang != '') then local:make-lang($lang) 
        else ())
    
};

(: Build basic triple string :)
declare function local:make-triple($s as xs:string?, $o as xs:string?, $p as xs:string?) as xs:string* {
    concat('&#xa;', $s,' ', $o,' ', $p, ' ;')
};

(: Places descriptions :)
declare function local:desc($rec) as xs:string* {
string-join(
for $desc in $rec/descendant::tei:desc
let $source := $desc/tei:quote/@source
return
    if($desc[@type='abstract'][not(@source)][not(tei:quote/@source)] or $desc[contains(@xml:id,'abstract')][not(@source)][not(tei:quote/@source)][. != '']) then 
        local:make-triple('', 'dcterms:description', local:make-literal($desc/text(),''))
    else 
        if($desc/child::* != '' or $desc != '') then 
            concat('&#xa; dcterms:description [',
                local:make-triple('','rdfs:label', local:make-literal($desc, string($desc/@xml:lang))),
                    if($source != '') then
                       if($desc/ancestor::tei:TEI/descendant::tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:availability/tei:licence/tei:p/tei:listBibl/tei:bibl/tei:ptr/@target = $source) then 
                            local:make-triple('','dcterms:license', local:make-uri(string($desc/ancestor::tei:TEI/descendant::tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:availability/tei:licence/@target)))
                       else ()
                    else (),
            '];')
        else (), '')
};

(: Places ids :)
declare function local:ids($rec) as xs:string* {
string-join(
for $id in $rec/descendant::tei:idno[@type='URI']
return 
    if($id[starts-with(.,'http://pleiades')]) then 
        local:make-triple('','skos:exactMatch',local:make-uri($id))
    else if($id[starts-with(.,'http://en.wikipedia.org')]) then 
        local:make-triple('','skos:closeMatch',local:make-uri($id))
    else (),''
    )
};

(: Place names :)
declare function local:names($rec) as xs:string*{
string-join(
for $name in $rec/descendant::tei:placeName
return 
    if($name/parent::tei:place) then 
        concat('&#xa; lawd:hasName [',
            if($name[contains(@syriaca-tags,'#syriaca-headword')]) then
               local:make-triple('','lawd:primaryForm',local:make-literal($name/text(),$name/@xml:lang)) 
            else local:make-triple('','lawd:variantForm',local:make-literal($name/text(),$name/@xml:lang)), 
        '];')    
    else   local:make-triple('','skos:related',local:make-literal($name/text(),$name/@xml:lang)),'')
};

(: Locations with coords :)
declare function local:geo($rec) as xs:string*{
string-join(
for $geo in $rec/descendant::tei:location[tei:geo]
return 
    concat('&#xa;geo:location [',
        local:make-triple('','geo:lat',local:make-literal(substring-before($geo/tei:geo,' '),'')),
        local:make-triple('','geo:long',local:make-literal(substring-after($geo/tei:geo,' '),'')),
    '];'),'')
};

(: Relations :)
declare function local:relation($rec) as xs:string*{
string-join(
for $relation in $rec/descendant::tei:relation
return 
    if($relation/@name = 'contained') then 
        for $active in tokenize($relation/@active,' ')
        return local:make-triple('','dcterms:isPartOf',local:make-uri($active))
    else if($relation/@name = 'share-a-name') then 
        let $rel := normalize-space($relation/@mutual)
        for $mutual in tokenize($rel,' ')
        return 
            if(starts-with($mutual,'#')) then ()
            else local:make-triple('','dcterms:relation',local:make-uri($mutual))
    else (),'')
};

(: Prefixes :)
declare function local:prefix() as xs:string{
"@prefix cito: <http://purl.org/spar/cito> .
@prefix cnt: <http://www.w3.org/2011/content#> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> .
@prefix geosparql: <http://www.opengis.net/ont/geosparql#> .
@prefix gn: <http://www.geonames.org/ontology#> .
@prefix lawd: <http://lawd.info/ontology/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix skos: <http://www.w3.org/2004/02/skos/core#> .
@prefix wdata: <https://www.wikidata.org/wiki/Special:EntityData/> .&#xa;"
};

(: Triples for a single record :)
declare function local:make-triples($rec) as xs:string*{
let $id := replace($rec/descendant::tei:idno[starts-with(.,'http://syriaca.org/')][1],'/tei','')
return 
    concat(
    local:make-triple(local:make-uri($id), 'a', 'lawd:Place'),
    local:make-triple('','rdfs:label', local:make-literal($rec/descendant::tei:titleStmt/tei:title[@level='a'][1]/descendant::text(),'')),
    local:names($rec),
    local:desc($rec),
    if($rec/descendant::tei:state[@type='existence'][@from]) then
        local:make-triple('','dcterms:temporal', local:make-literal($rec/descendant::tei:state[@type='existence']/@from,''))
    else (),
    local:ids($rec),
    local:geo($rec),
    local:make-triple('','foaf:primaryTopicOf', local:make-uri(concat($id,'/html'))),
    local:make-triple('','foaf:primaryTopicOf', local:make-uri(concat($id,'/tei'))),
    local:geo($rec),
    local:relation($rec)
    )
};

(: Make sure record ends with a '.' :)
declare function local:record($rec) as xs:string*{
    replace(local:make-triples($rec),';$','.&#xa;')
};

(: Get/save triples to db :)
if($id = 'run all') then 
    let $recs := collection('/db/apps/srophe-data/data/places/tei')
    (: Individual recs :)
    for $hit at $p in subsequence($recs, 1, 1000)//tei:TEI
    let $filename := concat(tokenize(replace($hit/descendant::tei:idno[@type='URI'][starts-with(.,'http://syriaca.org')][1],'/tei',''),'/')[last()],'.ttl')
    let $file-data :=  
        try {
            (concat(local:prefix(), local:record($hit)))
        } catch * {
            <error>Caught error {$err:code}: {$err:description}</error>
            }     
    return xmldb:store(xs:anyURI('/db/apps/bug-test/data'), xmldb:encode-uri($filename), $file-data)
else if($id = 'combined') then 
    (: Full collection:) 
    let $recs := collection('/db/apps/srophe-data/data/places/tei')
    let $full-rec := 
       string-join(
       for $hit in $recs
        let $filename := concat(tokenize(replace($hit/descendant::tei:idno[@type='URI'][starts-with(.,'http://syriaca.org')][1],'/tei',''),'/')[last()],'.ttl')
        let $file-data :=  
            try {
                local:record($hit)
            } catch * {
                <error>Caught error {$err:code}: {$err:description}</error>
                }
        return $file-data,'&#xa;')  
    let $full := concat(local:prefix(),$full-rec)    
    return xmldb:store(xs:anyURI('/db/apps/bug-test/data'), xmldb:encode-uri('all-places.ttl'), $full)
else if($id != '') then  
    let $recs := collection('/db/apps/srophe-data/data/places/tei')//tei:idno[@type='URI'][. = $id]
    (: Individual recs :)
    for $hit in $recs/ancestor::tei:TEI
    let $filename := concat(tokenize(replace($hit/descendant::tei:idno[@type='URI'][starts-with(.,'http://syriaca.org')][1],'/tei',''),'/')[last()],'.ttl')
    let $file-data :=  
        try {
            (concat(local:prefix(), local:record($hit)))
        } catch * {
            <error>Caught error {$err:code}: {$err:description}</error>
            }     
    return $file-data
    (:xmldb:store(xs:anyURI('/db/apps/bug-test/data/places/rdf'), xmldb:encode-uri($filename), $file-data):)
else ()