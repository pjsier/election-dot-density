.PHONY: all
.PRECIOUS: input/parcels.geojson

CANDIDATES = lightfoot preckwinkle daley wilson mendoza joyce chico enyia vallas mccarthy ford fioretti kozlar salesgriffin
CANDIDATE_FIELDS = lightfoot,preckwinkle,daley,wilson,mendoza,joyce,chico,enyia,vallas,mccarthy,ford,fioretti,kozlar,salesgriffin
RENAME_FIELDS = lightfoot="LORI LIGHTFOOT",preckwinkle="TONI PRECKWINKLE",daley="WILLIAM M. DALEY",wilson="WILLIE L. WILSON",mendoza="SUSANA A. MENDOZA",joyce="JERRY JOYCE",chico="GERY CHICO",enyia="AMARA ENYIA",vallas="PAUL VALLAS",mccarthy="GARRY MCCARTHY",ford="LA SHAWN K. FORD",fioretti="ROBERT 'BOB' FIORETTI",kozlar="JOHN KENNETH KOZLAR",salesgriffin="NEAL SALES-GRIFFIN"

all: aggregate-disser.jar

clean:
	rm -rf aggregate-disser.* aggregate-disser-master gradle-2.11* input/*.* candidates/*.* output/*.*

output/results.geojson: $(patsubst %, candidates/%.geojson, $(CANDIDATES))
	mapshaper -i $^ combine-files -merge-layers -o $@

candidates/%.geojson: candidates/%.csv
	mapshaper $< -points x=lon y=lat -each 'candidate = "$*"' -filter-fields candidate -o $@

candidates/%.csv: input/election.shp aggregate-disser.jar
	# TODO: Disaggregate into residential parcels
	java -jar aggregate-disser.jar --discrete $< $$(echo '$*' | cut -c1-10) input/election.shp ::area:: $@

input/parcels.shp: input/parcels.geojson
	mapshaper -i - -filter 'CLASS.startsWith("2-")' -filter-fields 'PIN14' -o $@ format=shapefile

input/parcels.geojson:
	esri2geojson --proxy "https://maps.cookcountyil.gov/cookviewer/proxy/tempProxy.ashx?" "https://gis1.cookcountyil.gov/arcgis/rest/services/cookVwrDynmc/MapServer/44" -v $@

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

gradle-2.11/bin/gradle: gradle-2.11.zip
	unzip $<

gradle-2.11.zip:
	wget -O $@ https://services.gradle.org/distributions/gradle-2.11-bin.zip
