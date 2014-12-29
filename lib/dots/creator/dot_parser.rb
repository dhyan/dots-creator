module DotParser

  def dot_boundry
    values = parsed_boundries_kml(self.url)
    data = dot_boundry_query(values)
    @result =  data.first.values.first
  end

  def dot_density(kml)
    values = parsed_values_kml(kml)
    @dot_results = []
    values.each do |value|
      polygon = parse_polygon_wkt(value.last)
      if polygon && value.first.to_i > 0
        population_count = value.first.to_i
        data =  dot_query_population(polygon,population_count)
        @dot_results << data.first.values.first
      end
    end
    return @dot_results
  end

  def parsed_boundries_kml(url)
    zip_path = kml_tmp_file(url)
    values = ""
    Zip::File.open(zip_path) do |file|
      file.each do |content|
        data = file.read(content)
        doc = Nokogiri::XML(data)
        # Parse and loop through each placemark
        doc.search('coordinates').each do |coordinate|
          values += "<Polygon>
          <outerBoundaryIs>
          <LinearRing>
          <coordinates>"
          values += coordinate.text
          values += "</coordinates>
          </LinearRing>
          </outerBoundaryIs>
          </Polygon>
          "
        end #placemark loop closed
      end #file loop
    end #zip closed
    return values
  end

  def kml_tmp_file(url)
     require 'zip'
    # Creating temp file, coz we cannot work on kml which is on server
    zipfile = Tempfile.new("file")
    zipfile.binmode
    zipfile.write(HTTParty.get(url).body)
    zipfile.close
    return  zipfile.path
  end


  def parsed_values_kml url
    zip_path = kml_tmp_file(url)
    values = []
    Zip::File.open(zip_path) do |file|
      file.each do |content|
        data = file.read(content)
        doc = Nokogiri::XML(data)
        # Parse and loop through each placemark
        doc.search('Placemark').each do |placemark|
          reach = placemark.search('reach').text.to_f #Get reach value for this particular region
          pop = placemark.search('population').text.to_f #Get population for this particular region
          pop_reach = ((reach * pop)/100).ceil #multiply reach and population and make 1 dot = 100 people
          # values[pop_reach] =  placemark.search('coordinates' ).text.split(',').first(2) if pop_reach
          values <<  [pop_reach,placemark.search('coordinates').text] if pop_reach
        end #placemark loop closed
      end #file loop

    end #zip closed
    return values
  end

  def parse_polygon_wkt(coordinates)
    polygon =  postgis_polygon_format(coordinates)
    begin
      #To convert string output to polygon format which is accepted by postgis
      result = RGeo::WKRep::WKTParser.new.parse(polygon)
    rescue
      #RGeo throws an error if polygon is not in proper format
      p "Error in polygon"
    end
    return result if result
  end

  #Method to convert co-ordinates to proper postgis polygon ordinates check Example below:
  #Co-ordinates which we are getting from kml
  #"138.617389,-34.847277,0.0 138.623819,-34.83836,0.0 138.626265,-34.839101,0.0 138.62826,-34.840926,0.0 138.627414,-34.842083,0.0 138.63027,-34.842786,0.0 138.632397,-34.844382,0.0 138.636907,-34.844163,0.0 138.639456,-34.842923,0.0 138.643924,-34.84318,0.0 138.645427,-34.84632,0.0 138.63534,-34.846848,0.0 138.626679,-34.847229,0.0 138.626291,-34.847246,0.0 138.62708,-34.858261,0.0 138.618189,-34.858708,0.0 138.617389,-34.847277,0.0"
  #Polygon format which is accepted by postgis
  #"POLYGON ((138.617389 -34.847277, 138.623819 -34.83836, 138.626265 -34.839101, 138.62826 -34.840926, 138.627414 -34.842083, 138.63027 -34.842786, 138.632397 -34.844382, 138.636907 -34.844163, 138.639456 -34.842923, 138.643924 -34.84318, 138.645427 -34.84632, 138.63534 -34.846848, 138.626679 -34.847229, 138.626291 -34.847246, 138.62708 -34.858261, 138.618189 -34.858708, 138.617389 -34.847277))"
  def postgis_polygon_format(coordinates)
    ordinates = 'POLYGON (('
    ordinates += coordinates.gsub("0.0", " ").gsub(",-"," -").gsub(/, $/, ")")
    ordinates += ')'
  end

  def dot_boundry_query(ordinates)
    begin
      old_logger = ActiveRecord::Base.logger
      ActiveRecord::Base.logger = nil
      ActiveRecord::Base.connection.execute("
      SELECT row_to_json(fc)
      FROM ( SELECT 'FeatureCollection' As type, array_to_json(array_agg(f)) As features
       FROM (SELECT 'Feature' As type
        , ST_AsGeoJSON(
          (ST_Union(geom))

          )::json As geometry
    , row_to_json((SELECT l FROM (SELECT '1' as color_code) As l
      )) As properties
    FROM ST_GeomFromKML('
      <MultiGeometry>
      #{ordinates}
      </MultiGeometry>
      ') AS geom
    ) As f )  As fc;
    ")
    ensure
      ActiveRecord::Base.logger = old_logger
    end
  end

  def dot_query_population(polygon,count)
    begin
      old_logger = ActiveRecord::Base.logger
      ActiveRecord::Base.logger = nil
      ActiveRecord::Base.connection.execute("
          CREATE OR REPLACE FUNCTION RandomPointsInPolygon(geom geometry, num_points integer)
          RETURNS SETOF geometry AS
          $BODY$DECLARE
          target_proportion numeric;
          n_ret integer := 0;
          loops integer := 0;
          x_min float8;
          y_min float8;
          x_max float8;
          y_max float8;
          srid integer;
          rpoint geometry;
          BEGIN
          -- Get envelope and SRID of source polygon
          SELECT ST_XMin(geom), ST_YMin(geom), ST_XMax(geom), ST_YMax(geom), ST_SRID(geom)
          INTO x_min, y_min, x_max, y_max, srid;
          -- Get the area proportion of envelope size to determine if a
          -- result can be returned in a reasonable amount of time
          SELECT ST_Area(geom)/ST_Area(ST_Envelope(geom)) INTO target_proportion;
          RAISE DEBUG 'geom: SRID %, NumGeometries %, NPoints %, area proportion within envelope %',
          srid, ST_NumGeometries(geom), ST_NPoints(geom),
          round(100.0*target_proportion, 2) || '%';
          IF target_proportion < 0.0001 THEN
          RAISE EXCEPTION 'Target area proportion of geometry is too low (%)',
          100.0*target_proportion || '%';
          END IF;
          RAISE DEBUG 'bounds: % % % %', x_min, y_min, x_max, y_max;

          WHILE n_ret < num_points LOOP
          loops := loops + 1;
          SELECT ST_SetSRID(ST_MakePoint(random()*(x_max - x_min) + x_min,
           random()*(y_max - y_min) + y_min),
srid) INTO rpoint;
IF ST_Contains(geom, rpoint) THEN
n_ret := n_ret + 1;
RETURN NEXT rpoint;
END IF;
END LOOP;
RAISE DEBUG 'determined in % loops (% efficiency)', loops, round(100.0*num_points/loops, 2) || '%';
END$BODY$
LANGUAGE plpgsql VOLATILE
COST 100
ROWS 1000;
ALTER FUNCTION RandomPointsInPolygon(geometry, integer) OWNER TO #{Rails.configuration.database_configuration[Rails.env]["username"]};



SELECT row_to_json(fc)
FROM ( SELECT 'FeatureCollection' As type, array_to_json(array_agg(f)) As features
 FROM (SELECT 'Feature' As type
  , ST_AsGeoJSON(
    (ST_Union(geom))

    )::json As geometry
, row_to_json((SELECT l FROM (SELECT '1' as color_code) As l
  )) As properties
FROM RandomPointsInPolygon('#{polygon}', #{count}) AS geom
) As f )  As fc;
")
    ensure
      ActiveRecord::Base.logger = old_logger
    end
  end

end