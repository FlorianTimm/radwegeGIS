<%@ page contentType="application/json" language="java" import="java.sql.* " %>
<%@ page import="java.io.*" %>
<%
try {
String driver = "org.postgresql.Driver";
String url = "jdbc:postgresql://localhost:5433/geo";
String username = "postgres";
String password = "Hamburg01!";
String myDataField = null;
String myQuery = "select row_to_json(fc) t from (select 'FeatureCollection' as \"type\", json_build_object('type', 'name', 'properties', json_build_object('name', 'EPSG:25832')) as \"crs\",array_to_json(array_agg(f)) as \"features\" from (select 'Feature' as \"type\", radweg_id as \"id\", ST_AsGeoJSON(ST_Transform(geometrie, 25832), 6) :: json as \"geometry\",(select json_strip_nulls(row_to_json(t)) from (select strassenname, richtung, oberflaeche, radweg_art, niveau, status, quelle, id_in_quelle, to_char(create_date, 'DD.MM.YYYY') stand) t) as \"properties\" from radverkehr.v_radweg) as f) as fc;";
Connection myConnection = null;
PreparedStatement myPreparedStatement = null;
ResultSet myResultSet = null;
Class.forName(driver).newInstance();
myConnection = DriverManager.getConnection(url,username,password);
myPreparedStatement = myConnection.prepareStatement(myQuery);
myResultSet = myPreparedStatement.executeQuery();
if(myResultSet.next())
myDataField = myResultSet.getString("t");
out.print(myDataField);
}
catch(ClassNotFoundException e){e.printStackTrace();}
catch (SQLException ex)
{
out.print("SQLException: "+ex.getMessage());
out.print("SQLState: " + ex.getSQLState());
out.print("VendorError: " + ex.getErrorCode());
}
%>