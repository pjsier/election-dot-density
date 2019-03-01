.PHONY: all deploy
.PRECIOUS: input/parcels.geojson input/parcels.shp

S3_BUCKET = chicago-election-2019
CANDIDATES = lightfoot preckwinkle daley wilson mendoza joyce chico enyia vallas mccarthy ford fioretti kozlar salesgriffin
CANDIDATE_FIELDS = lightfoot,preckwinkle,daley,wilson,mendoza,joyce,chico,enyia,vallas,mccarthy,ford,fioretti,kozlar,salesgriffin
RENAME_FIELDS = lightfoot="LORI LIGHTFOOT",preckwinkle="TONI PRECKWINKLE",daley="WILLIAM M. DALEY",wilson="WILLIE L. WILSON",mendoza="SUSANA A. MENDOZA",joyce="JERRY JOYCE",chico="GERY CHICO",enyia="AMARA ENYIA",vallas="PAUL VALLAS",mccarthy="GARRY MCCARTHY",ford="LA SHAWN K. FORD",fioretti="ROBERT 'BOB' FIORETTI",kozlar="JOHN KENNETH KOZLAR",salesgriffin="NEAL SALES-GRIFFIN"
mapshaper_cmd = node --max_old_space_size=4096 $$(which mapshaper)

all: tiles

deploy:
	aws s3 cp ./tiles s3://$(S3_BUCKET)/results-dot-density/ --recursive --acl=public-read --content-encoding=gzip --region=us-east-1
	aws s3 cp index.html s3://$(S3_BUCKET)/results-dot-density/index.html --acl=public-read --region=us-east-1
	aws s3 cp style.json s3://$(S3_BUCKET)/results-dot-density/style.json --acl=public-read --region=us-east-1

tiles: output/results.mbtiles
	mkdir -p $@
	tile-join --no-tile-size-limit --force -e ./tiles $<

output/results.mbtiles: output/results.geojson
	tippecanoe -L results:$< --drop-densest-as-needed --maximum-zoom=11 --no-tile-stats --force -B9 --maximum-tile-bytes=1000000 -o $@

output/results.geojson: $(patsubst %, candidates/%.geojson, $(CANDIDATES))
	mapshaper -i $^ combine-files -merge-layers -o $@

candidates/%.geojson: candidates/%.csv
	mapshaper $< -points x=lon y=lat -each 'candidate = "$*"' -filter-fields candidate -o $@

candidates/%.csv: input/election.shp input/parcels.shp aggregate-disser.jar
	java -jar aggregate-disser.jar --discrete $< $$(echo '$*' | cut -c1-10) input/parcels.shp ::area:: $@

input/parcels.shp: input/cook-parcels.geojson input/clip.geojson
	$(mapshaper_cmd) -i $< \
	-erase $(filter-out $<,$^) remove-slivers \
	-filter '!!BLDGClass && BLDGClass.startsWith("2")' \
	-filter-fields PIN14 \
	-o $@ format=shapefile

# Create a file with all of Cook County excluding Chicago for erasing from the parcel layer
input/clip.geojson: input/cook.geojson input/chicago.geojson
	$(mapshaper_cmd) -i $< -erase $(filter-out $<,$^) remove-slivers -o $@

input/cook.geojson:
	wget -O $@ 'https://datacatalog.cookcountyil.gov/api/geospatial/ihae-id2m?method=export&format=GeoJSON'

input/chicago.geojson:
	wget -O $@ 'https://data.cityofchicago.org/api/geospatial/sp34-6z76?method=export&format=GeoJSON'

input/cook-parcels.geojson:
	esri2geojson -f PIN14,BLDGClass --proxy "https://maps.cookcountyil.gov/cookviewer/proxy/tempProxy.ashx?" "https://gis1.cookcountyil.gov/arcgis/rest/services/cookVwrDynmc/MapServer/44" -v $@

input/election.shp:
	wget -q -O - $@ https://raw.githubusercontent.com/datamade/chicago-municipal-elections/master/data/municipal_general_2019.geojson | \
	mapshaper -i - \
	-rename-fields $(RENAME_FIELDS) \
	-filter-fields $(CANDIDATE_FIELDS) \
	 -o $@ format=shapefile

aggregate-disser.jar: gradle-2.11/bin/gradle aggregate-disser-master
	$(eval repo=$(filter-out $<,$^))
	./$< -p ./$(repo) fatJar
	mv ./$(repo)/build/libs/$(repo).jar $@

aggregate-disser-master: aggregate-disser.zip
	unzip $<

aggregate-disser.zip:
	wget -O $@ https://github.com/conveyal/aggregate-disser/archive/master.zip

# aggregate-disser requires an old version of gradle to build
gradle-2.11/bin/gradle: gradle-2.11.zip
	unzip $<

gradle-2.11.zip:
	wget -O $@ https://services.gradle.org/distributions/gradle-2.11-bin.zip
