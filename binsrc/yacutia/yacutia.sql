--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
--  
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--  
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--  
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--  
--  
-- $Id$

/* Aggregate concat */

create procedure yac_rep_exec (in _attached_qual varchar, in _attached_owner varchar, in _attached_name varchar,
			       inout _stmt any, inout _stat any, inout _msg any)
{
   _stmt := replace (_stmt, '''', '''''');
   _stmt := sprintf ('create nonincremental snapshot "%I"."%I"."%I" as ''%s''',
	 _attached_qual, _attached_owner, _attached_name, _stmt);
   return exec (_stmt, _stat, _msg);
}
;


create function yac_agg_concat_init (inout _agg varchar)
{
  _agg := ''; -- The "accumulator" is a string session. Initially it is empty.
};

create function yac_agg_concat_acc (
  inout _agg any,		-- The first parameter is used for passing "accumulator" value.
  in _val varchar,	-- Second parameter gets the value passed by first parameter of aggregate call.
  in _sep varchar )	-- Third parameter gets the value passed by second parameter of aggregate call.
{
  if (_val is null)	-- Attributes with NULL names should not affect the result.
    return;
  if (_sep is null)
    _agg := concat (_agg, _val);
  else
    _agg := concat (_agg, _val, _sep);
};

create function yac_agg_concat_final (inout _agg any) returns varchar
{
  declare _res varchar;
  if (_agg is null)
    return '';
  _res := _agg;
  return _res;
};

create aggregate yac_agg_concat (in _val varchar, in _sep varchar) returns varchar
  from yac_agg_concat_init, yac_agg_concat_acc, yac_agg_concat_final;

/* /Aggregate concat */


create procedure
yacutia_exec_no_error (in expr varchar)
{
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

create procedure
get_xml_meta ()
{
  declare mtd, dta any;
  exec ('select top 1 xtree_doc(''<q/>'') from db.dba.sys_users',
        null, null, vector (), -1, mtd, dta );
  return mtd[0];
}
;

create procedure
yacutia_pars_http_log_file (in log_file_name varchar,
                            inout pattern varchar,
                            inout r_sel varchar,
                            inout _type any)
{
   declare one_line varchar;
   declare pos, idx, len integer;
   declare res, res_line any;
   declare temp, l_part, _all any;

--   declare log_file_name varchar;
--   log_file_name := 'http05082002.log';

   _all := file_to_string (log_file_name);
   _all := split_and_decode (_all, 0, '\0\0\n');

   idx := 0;
   len := length (_all) - 1;
   res := vector ();
   _type := atoi (_type);

   while (idx < len)
     {
  one_line := _all [idx];

  pos := strstr (one_line, '[');
  l_part := "LEFT" (one_line, pos - 1);
  one_line := "RIGHT" (one_line, length (one_line) - pos);
  res_line := split_and_decode (l_part, 0, '\0\0 ');
  temp := split_and_decode (one_line, 0, '\0\0]');
  res_line := vector_concat (res_line, vector (concat (temp[0], ']')));
  one_line := "RIGHT" (one_line, length (one_line) - length (temp[0]) - 2);
  temp := split_and_decode (one_line, 0, '\0\0"');
  res_line := vector_concat (res_line, vector (temp[1]));
  res_line := vector_concat (res_line, split_and_decode (trim (temp[2]),  0, '\0\0 '));
  res_line := vector_concat (res_line, vector (temp[3]));
  res_line := vector_concat (res_line, vector (temp[5]));

        if (pattern <> '')
          {
--
--    FILTER
--
             if (not _type)
               {
       declare idx_f, fl integer;

       idx_f := 0;
       fl := 0;

       while (idx_f < length(res_line))
         {
            if (strstr (res_line[idx_f], pattern) is not NULL)
        fl := 1;
            idx_f := idx_f + 1;
         }

       if (fl and (yacutia_pars_http_radio_sel (res_line, r_sel)))
          res := vector_concat (res, vector (res_line));
               }
             else
               {
                   if (strstr (res_line[_type-1], pattern) and
                       (yacutia_pars_http_radio_sel (res_line, r_sel)))
          res := vector_concat (res, vector (res_line));
               }
          }
        else
          {
             if (yacutia_pars_http_radio_sel (res_line, r_sel))
         res := vector_concat (res, vector (res_line));
          }

  idx := idx + 1;
     }

   return res;
}
;

create procedure
yacutia_pars_http_radio_sel (inout _line any, in _mode varchar)
{
   if (_mode = 'all') return 1;
   if (_mode = 'fail' and _line[5] <> '200') return 1;
   if (_mode = 'succ' and _line[5] = '200') return 1;
   return 0;
}
;

create procedure
yacutia_http_log_ui_labels ()
{
   return vector ('Remote Host', 'User Name', 'Auth user', 'Datetime', 'Request',
                  'Status', 'Bytes', 'Referrer', 'User Agent');
}
;

/*
  IMPORTANT:
  Keep the ID number consistent to track pages,
  for pages that are not part of navigation bar
  put place="1" attribute, for top level items put a url for default
  second level
*/

create procedure adm_menu_tree ()
{
  declare wa_available integer;
  wa_available := gt (DB.DBA.VAD_CHECK_VERSION ('wa'), '1.02.13');
  return concat (
'<?xml version="1.0" ?>
<adm_menu_tree>
 <node name="Home" url="main_tabs.vspx" id="1" tip="Common Tasks" allowed="yacutia_admin">
 </node>
 <node name="System Admin" url="sys_info.vspx" id="2" tip="Administer the Virtuoso server" allowed="yacutia_admin">
   <node name="Dashboard" url="sys_info.vspx"  id="171" allowed="yacutia_admin">
     <node name="Dashboard Properties" url="dashboard.vspx" id="167" place="1" allowed="yacutia_admin"/>
   </node>
   <node name="User Accounts" url="accounts_page.vspx"  id="3" allowed="yacutia_accounts_page">
     <node name="Accounts" url="accounts.vspx" id="4" place="1" allowed="yacutia_accounts_page"/>
     <node name="Accounts" url="account_create.vspx" id="5" place="1" allowed="yacutia_accounts_page"/>
     <node name="Accounts" url="account_remove.vspx" id="6" place="1" allowed="yacutia_accounts_page"/>
     <node name="Roles" url="roles.vspx" id="7" place="1" allowed="yacutia_accounts_page"/>
     <node name="Roles" url="role_remove.vspx" id="8" place="1" allowed="yacutia_accounts_page"/>
     <node name="Grants" url="capabilities.vspx" id="9" place="1" allowed="yacutia_accounts_page"/>
     <node name="Grants" url="caps_browser.vspx" id="10" place="1" allowed="yacutia_accounts_page"/>
     <node name="Grants" url="caps_cols_browser.vspx" id="11" place="1" allowed="yacutia_accounts_page"/>
     <node name="LDAP Import" url="ldap_import.vspx" place="1" id="12" allowed="yacutia_accounts_page" />
     <node name="LDAP Import" url="ldap_import_1.vspx" place="1" id="14" allowed="yacutia_accounts_page"/>
     <node name="LDAP Import" url="ldap_import_2.vspx" place="1" id="15" allowed="yacutia_accounts_page"/>
     <node name="LDAP Import" url="ldap_import_3.vspx" place="1" id="16" allowed="yacutia_accounts_page"/>
     <node name="LDAP Servers" url="ldap_server.vspx" id="179" place="1" allowed="yacutia_accounts_page"/>
   </node>
   <node name="Scheduler" url="sys_queues.vspx"  tip="Event Scheduling" id="17" allowed="yacutia_queues_page">
     <node name="Scheduler" url="sys_queues.vspx" id="18" place="1" allowed="yacutia_queues_page">
       <node name="Scheduler" url="sys_queues_edit.vspx" id="19" place="1" allowed="yacutia_queues_page"/>
       <node name="Scheduler" url="sys_queues_remove.vspx" id="20" place="1" allowed="yacutia_queues_page"/>
       <node name="Scheduler" url="sys_queues_error.vspx" id="166" place="1" allowed="yacutia_queues_page"/>
     </node>
   </node>
   <node name="Parameters" url="inifile.vspx?page=Database"  id="21" allowed="yacutia_params_page">
     <node name="Parameters" url="inifile.vspx" id="22" place="1" allowed="yacutia_params_page"/>
   </node>
   <node name="Access Control" url="sec_auth_serv.vspx"  id="23" allowed="yacutia_acl_page">
     <node name="ACL List" url="sec_auth_serv.vspx" id="24" place="1" allowed="yacutia_acl_page">
      <node name="ACL List" url="sec_auth_serv.vspx" id="25" place="1" allowed="yacutia_acl_page"/>
      <node name="ACL Edit" url="sec_acl_edit.vspx" id="26" place="1" allowed="yacutia_acl_page"/>
     </node>
   </node>
   <node name="Packages" url="vad.vspx"  id="27" allowed="yacutia_vad_page">
     <node name="Packages" url="vad.vspx"  id="28" place="1" allowed="yacutia_vad_page"/>
     <node name="Install packages" url="vad_install.vspx"  id="29" place="1" allowed="yacutia_vad_page"/>
     <node name="Remove packages" url="vad_remove.vspx"  id="30" place="1" allowed="yacutia_vad_page"/>
     <node name="Package status" url="vad_status.vspx"  id="31" place="1" allowed="yacutia_vad_page"/>
     <node name="WA Package" url="vad_wa_config.vspx"  id="32" place="1" allowed="yacutia_vad_page"/>
     <node name="WA Package" url="vad_wa_create.vspx"  id="312" place="1" allowed="yacutia_vad_page"/>
   </node>
   <node name="Monitor" url="logging_page.vspx"  id="33" allowed="yacutia_loging_page">
     <node name="Version &amp; License Info" url="logging.vspx"  id="34" place="1" allowed="yacutia_loging_page"/>
     <node name="DB Server Statistics" url="logging_db.vspx"  id="35" place="1"  allowed="yacutia_loging_page"/>
     <node name="Disk Statistics" url="logging_disk.vspx"   id="36" place="1" allowed="yacutia_loging_page"/>
     <node name="Index Statistics" url="logging_index.vspx"  id="37" place="1" allowed="yacutia_loging_page"/>
     <node name="Lock Statistics" url="logging_lock.vspx"  id="38" place="1" allowed="yacutia_loging_page"/>
     <node name="Space Statistics" url="logging_space.vspx"  id="39" place="1" allowed="yacutia_loging_page"/>
     <node name="HTTP Server Statistics" url="logging_http.vspx"    id="40" place="1" allowed="yacutia_loging_page"/>
     <node name="Profiling" url="logging_prof.vspx"   id="41" place="1" allowed="yacutia_loging_page"/>
     <node name="Log Viewer" url="logging_view.vspx"   id="42" place="1" allowed="yacutia_loging_page"/>
   </node>
 </node>
 <node name="Database" url="databases.vspx"  id="43" tip="Database Server local and remote resource manipulation" allowed="yacutia_db">
   <node name="Schema Objects" url="databases.vspx"  id="44" allowed="yacutia_databases_page">
     <node name="Databases-drop" url="databases_drop.vspx" id="45" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-drop" url="db_drop_conf.vspx" id="46" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-drop" url="db_drop_errs.vspx" id="47" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-table-edit" url="databases_table_edit.vspx" id="48" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-table-constraints" url="databases_table_constraints.vspx" id="49" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-constraints-drop" url="db_const_drop_conf.vspx" id="50" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-constraints-drop" url="db_const_drop_errs.vspx" id="51" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-view-edit" url="databases_view_edit.vspx" id="52" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-proc-edit" url="databases_proc_edit.vspx" id="53" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-udt-edit" url="databases_udt_edit.vspx" id="54" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-export" url="ie.vspx" id="176" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-export" url="databases_export.vspx" id="177" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-grants" url="databases_grants.vspx" id="191" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-grants" url="db_grant_many.vspx" id="192" place="1" allowed="yacutia_databases_page"/>
     <node name="Databases-grants" url="db_grant_errs.vspx" id="193" place="1" allowed="yacutia_databases_page"/>
   </node>',
--   <node name="Schema Editor" url="xddl.vspx?init=xddl"  id="52" allowed="yacutia_xddl_page">
--     <node name="edit" url="xddl.vspx" id="53" place="1" allowed="yacutia_xddl_page"/>
--     <node name="edit" url="xddl2.vspx" id="54" place="1" allowed="yacutia_xddl_page"/>
--   </node>
  '<node name="External Data Sources" url="vdb_linked_obj.vspx"  id="55" allowed="yacutia_remote_data_access_page">
     <node name="VDB Management" url="vdb_unlink_obj.vspx" id="56" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conn_dsn.vspx" id="57" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_config_dsn.vspx" id="58" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conn_dsn_edit.vspx" id="59" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conn_dsn_del.vspx" id="174" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_obj_link.vspx" id="60" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_obj_link_opts.vspx" id="61" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_obj_link_pk.vspx" id="172" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conf_dsn_remove.vspx" id="62" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conf_dsn_edit.vspx" id="63" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_conf_dsn_new.vspx" id="64" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Management" url="vdb_main.vspx" id="65" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="Known Datasources" url="vdb_dsns.vspx" id="66" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="VDB Errors" url="vdb_errs.vspx" id="67" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="Known External Resources" url="vdb_resources.vspx" id="68" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="Link External Resources" url="vdb_link.vspx" id="69" place="1" allowed="yacutia_remote_data_access_page"/>
     <node name="Edit Datasource" url="vdb_dsn_edit.vspx" id="70" place="1" allowed="yacutia_remote_data_access_page"/>
   </node>
   <node name="Interactive SQL" url="isql_main.vspx"  id="71" allowed="yacutia_isql_page"/>
   <node name="User Defined Types" url="hosted_page.vspx"  id="72" allowed="yacutia_runtime">
     <node name="Loaded Modules" url="hosted_modules.vspx" id="73" place="1" allowed="yacutia_runtime_loaded"/>
     <node name="Import Files" url="hosted_import.vspx" id="74" place="1" allowed="yacutia_runtime_import"/>
     <node name="Import Files Results" url="hosted_modules_load_results.vspx" id="75" place="1" allowed="yacutia_runtime_import_result"/>
     <node name="Load Modules" url="hosted_modules_select.vspx" id="76" place="1" allowed="yacutia_runtime_loaded_select"/>
     <node name="Load Modules" url="hosted_modules_select2.vspx" id="77" place="1" allowed="yacutia_runtime_loaded_select2"/>
     <node name="Modules Grant" url="hosted_grant.vspx" id="78" place="1" allowed="yacutia_runtime_hosted_grant"/>
   </node>
   <node name="Backup" url="db_backup.vspx"  id="79" allowed="yacutia_backup_page">
     <node name="Backup" url="db_backup_clear.vspx" id="169" place="1" allowed="yacutia_backup_page"/>
   </node>
 </node>
 <node name="Replication"  url="db_repl_basic.vspx" id="80" tip="Replications" allowed="yacutia_repl">
   <node name="Basic" url="db_repl_basic.vspx"  id="8001" >
    <node name="Basic" url="db_repl_basic_create.vspx" id="8002" place="1" />
    <node name="Basic" url="db_repl_basic_local.vspx" id="8011" place="1" />
    <node name="Basic" url="db_repl_basic_local_create.vspx" id="8012" place="1" />
   </node>
   <node name="Incremental" url="db_repl_snap.vspx"  id="81" >
    <node name="Incremental" url="db_repl_snap_create.vspx" id="82" place="1" />
    <node name="Incremental" url="db_repl_snap_pull.vspx" id="83" place="1"/>
    <node name="Incremental" url="db_repl_snap_pull_create.vspx" id="84" place="1" />
    <node name="Incremental" url="db_repl_snap_local.vspx" id="85" place="1"/>
    <node name="Incremental" url="db_repl_snap_local_create.vspx" id="86" place="1" />
   </node>
   <node name="Bidirectional Snapshot" url="db_repl_bi.vspx" id="87" >
    <node name="Bidirectional Snapshot" url="db_repl_bi_create.vspx" id="88" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_bi_edit.vspx" id="89" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_bi_add.vspx" id="90" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_cr_edit.vspx" id="91" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_bi_remove.vspx" id="92" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_bi_cr.vspx" id="93" place="1" />
    <node name="Bidirectional Snapshot" url="db_repl_bi_cr_edit.vspx" id="94" place="1" />
   </node>
   <node name="Transactional" url="db_repl_trans.vspx" id="95" >
      <node name="Transactional (publish)" url="db_repl_pub.vspx"  id="96" place="1"/>
      <node name="Transactional (publish)" url="db_repl_pub_create.vspx" id="97" place="1" />
      <node name="Transactional (publish)" url="db_repl_pub_edit.vspx" id="98" place="1" />
      <node name="Transactional (publish)" url="db_repl_pub_cr.vspx" id="99" place="1" />
      <node name="Transactional (publish)" url="db_repl_pub_cr_edit.vspx" id="100" place="1" />
      <node name="Transactional (publish)" url="db_repl_pub_cr_edit2.vspx" id="101" place="1" />
      <node name="Transactional (subscribe)" url="db_repl_sub.vspx"   id="102" place="1"/>
      <node name="Transactional (subscribe)" url="db_repl_sub_create.vspx" id="103" place="1" />
      <node name="Transactional (subscribe)" url="db_repl_sub_image.vspx" id="104" place="1" />
      <node name="Transactional (publish)" url="db_repl_sub_edit.vspx" id="105" place="1" />
   </node>
 </node>
 <node name="WebDAV &amp; HTTP" url="cont_page.vspx"  id="138" tip="Web server DAV repository and Web site hosting control" allowed="yacutia_http">
   <node name="WebDAV Content Management" url="cont_page.vspx"  id="139" allowed="yacutia_http_content_page">
      <node name="Content Management" url="cont_page.vspx" id="140" place="1" allowed="yacutia_http_content_page"/>
      <node name="Content Management" url="cont_management.vspx" id="141" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_control.vspx" id="142" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_edit.vspx" id="143" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_queues.vspx" id="144" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_sites.vspx" id="145" place="1"  allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_status.vspx" id="146" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_urls_list.vspx" id="147" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_sched.vspx" id="148" place="1" allowed="yacutia_http_content_page"/>
      <node name="Robot Control" url="robot_export.vspx" id="168" place="1" allowed="yacutia_http_content_page"/>
      <node name="Text Triggers" url="text_triggers.vspx" id="149" place="1" allowed="yacutia_http_content_page"/>
      <node name="Resource Types" url="cont_management_types.vspx" id="150" place="1" allowed="yacutia_http_content_page"/>
      <node name="Resource Types" url="cont_type_edit.vspx" id="151" place="1" allowed="yacutia_http_content_page"/>
      <node name="Resource Types" url="cont_type_remove.vspx" id="152" place="1" allowed="yacutia_http_content_page"/>
   </node>
   <node name="HTTP Hosts &amp; Directories" url="http_serv_mgmt.vspx"  id="153" allowed="yacutia_http_server_management_page">
      <node name="Edit Paths" url="http_edit_paths.vspx" id="154" place="1" allowed="yacutia_http_server_management_page"/>
      <node name="Add Path" url="http_add_path.vspx" id="155" place="1" allowed="yacutia_http_server_management_page"/>
      <node name="Edit Host" url="http_host_edit.vspx" id="170" place="1" allowed="yacutia_http_server_management_page"/>
      <node name="Clone Host" url="http_host_clone.vspx" id="175" place="1" allowed="yacutia_http_server_management_page"/>
      <node name="Delete Path" url="http_del_path.vspx" id="156" place="1" allowed="yacutia_http_server_management_page"/>
   </node>
 </node>
 <node name="XML" url="xml_sql.vspx"  id="106" tip="XML Services permit manipulation of XML data from stored and SQL sources" allowed="yacutia_xml">
   <node name="SQL-XML" url="xml_sql.vspx"  id="107" allowed="yacutia_sql_xml_page">
     <node name="SQL-XML" url="xml_sql2.vspx" id="108" place="1" allowed="yacutia_sql_xml_page">
     </node>
   </node>
   <node name="XSL Transformation" url="xslt.vspx"  id="109" allowed="yacutia_xslt_page">
     <node name="XSLT" url="xslt_result.vspx" id="110" place="1" allowed="yacutia_xslt_page">
     </node>
   </node>
   <node name="XQuery" url="xquery.vspx"  id="111" allowed="yacutia_xquery_page">
     <node name="XQuery" url="xquery.vspx" id="112" place="1" allowed="yacutia_xquery_page" />
     <node name="XQuery" url="xquery2.vspx" id="113" place="1" allowed="yacutia_xquery_page"/>
     <node name="XQuery" url="xquery3.vspx" id="114" place="1" allowed="yacutia_xquery_page"/>
     <node name="XQuery" url="xquery4.vspx" id="115" place="1" allowed="yacutia_xquery_page"/>
     <node name="XQuery" url="xquery_templates.vspx" id="173" place="1" allowed="yacutia_xquery_page"/>
     <node name="XQuery" url="xquery_adv.vspx" id="178" place="1" allowed="yacutia_xquery_page"/>
   </node>',
--   <node name="XML Schema" url="xml_xsd.vspx"  id="116" allowed="yacutia_xml_schema_check_page">
--      <node name="XML Schema" url="xml_xsd.vspx" id="117" place="1" allowed="yacutia_xml_schema_check_page"/>
--   </node>
--   <node name="Mapping Schema" url="mapped_schema_xml.vspx"  id="118" allowed="yacutia_mapped_schema_page">
--      <node name="Mapping Schema" url="mapped_schema_xml.vspx" id="119" place="1" allowed="yacutia_mapped_schema_page"/>
--   </node>
 '</node>
 <node name="Web Services" url="soap_services.vspx"  id="120" tip="Web Services permit the exposure and consumption of functions for distributed applications" allowed="yacutia_web">
   <node name="Web Service Endpoints" url="soap_services.vspx"  id="121" allowed="yacutia_soap_page">
     <node name="Web Service Endpoint Edit" url="soap_services_list.vspx" id="122" place="1" allowed="yacutia_soap_page"/>
     <node name="Web Service Endpoint List" url="soap_services_edit.vspx" id="123" place="1" allowed="yacutia_soap_page"/>
     <node name="Web Service Endpoint List" url="soap_options_edit.vspx" id="124" place="1" allowed="yacutia_soap_page"/>
     <node name="Delete Web Service Endpoint" url="soap_del_path.vspx" id="165" place="1" allowed="yacutia_soap_page"/>
   </node>
   <node name="WSDL Import / Export" url="wsdl_services.vspx"  id="125" allowed="yacutia_wsdl_page">
     <node name="Import" url="wsdl_services.vspx" id="126" place="1" allowed="yacutia_wsdl_page">
       <node name="Import" url="wsdl_services.vspx" id="127" place="1" allowed="yacutia_wsdl_page"/>
     </node>
     <node name="Create" url="wsdl_service_create.vspx" id="128" place="1" allowed="yacutia_wsdl_page">
       <node name="Create" url="wsdl_service_create.vspx" id="129" place="1" allowed="yacutia_wsdl_page"/>
     </node>
   </node>
   <node name="BPEL" url="bpel_service.vspx" id="165" allowed="yacutia_bpel_page"/>',
--   <node name="UDDI Services" url="uddi_serv.vspx"  id="130" allowed="yacutia_uddi_page">
--     <node name="Server" url="uddi_serv.vspx" id="131" place="1" allowed="yacutia_uddi_page"/>
--     <node name="Browse" url="uddi_serv_browse.vspx" id="132" place="1" allowed="yacutia_uddi_page"/>
--     <node name="Create" url="uddi_serv_create.vspx" id="133" place="1" allowed="yacutia_uddi_page"/>
--     <node name="Find" url="uddi_serv_find.vspx" id="134" place="1" allowed="yacutia_uddi_page"/>
--     <node name="Remove" url="uddi_remove.vspx" id="135" place="1" allowed="yacutia_uddi_page"/>
--   </node>',
--case wa_available
--when 1 then '<node name="Applications" url="site.vspx"  id="136" allowed="yacutia_app_page">
--               <node name="edit" url="site.vspx" id="137" place="1" allowed="yacutia_app_page"/>
--             </node>'
--when 0 then '' end,
'</node>
 <node name="RDF" url="sparql_input.vspx"  id="189" tip="RDF " allowed="yacutia_message">',
  '<node name="SPARQL" url="sparql_input.vspx"  id="180" allowed="yacutia_sparql_page">
     <node name="SPARQL" url="sparql_load.vspx" id="181" place="1" allowed="yacutia_sparql_page" />
   </node>',
'</node>
 <node name="NNTP" url="msg_news_conf.vspx"  id="157" tip="Mail and news messaging" allowed="yacutia_message">',
   --<node name="Mail Configuration" url="msg_mail_conf.vspx"  id="158" yacutia_mail_config_page"">
   --</node>
   '<node name="News Servers" url="msg_news_conf.vspx"  id="159" allowed="yacutia_news_config_page">
     <node name="News Groups" url="msg_news_groups.vspx" id="160" place="1"  allowed="yacutia_news_config_page"/>
     <node name="News Group Subscripting" url="msg_news_group_subscribe.vspx" id="161" place="1"  allowed="yacutia_news_config_page"/>
     <node name="News Group Messages" url="msg_news_group_messages.vspx" id="162" place="1"  allowed="yacutia_news_config_page"/>
     <node name="News Group Message Body" url="msg_news_group_message_body.vspx" id="163" place="1"  allowed="yacutia_news_config_page"/>
     <node name="News Server Global" url="msg_news_conf_global.vspx" id="164" place="1"  allowed="yacutia_news_config_page"/>
   </node>
 </node>
</adm_menu_tree>');
}
;


create procedure
adm_navigation_root (in path varchar)
{
  return xpath_eval ('/adm_menu_tree/*', xml_tree_doc (adm_menu_tree ()), 0);
}
;


create procedure adm_belongs_to (in page any, in refr any)
{
  declare tree, page1, page2, tmp, part any;
  tree := xtree_doc (adm_menu_tree ());
  tmp := split_and_decode (page, 0, '\0\0/');
  page1 := tmp[length (tmp) - 1];
  tmp := split_and_decode (refr, 0, '\0\0/');
  page2 := tmp[length (tmp) - 1];
  part := xpath_eval (sprintf ('/adm_menu_tree//node[@url = "%s"]//node[@url = "%s" and @place="1" ]', page1, page2), tree);
  if (part is not null)
    {
      return 1;
    }
  return 0;
}
;

/*
  Conductor routines
*/

create procedure
adm_navigation_child (in path varchar, in node any)
{
  path := concat (path, '[not @place]');
  return xpath_eval (path, node, 0);
}
;

create procedure
adm_get_node_by_url (in url varchar)
{
  declare page varchar;
  declare part any;
  declare xt any;
  xt := xml_tree_doc (adm_menu_tree ());
  page := split_and_decode (url, 0, '\0\0/');
  page := page[length (page) - 1];
  part := xpath_eval (sprintf ('/adm_menu_tree//node[@url = "%s"]/parent::node', page), xt, 1);
  return vector (serialize(part));
}
;

create procedure
adm_db_tree_1 ()
{
  declare res varchar;
  declare i int;
  set isolation='uncommitted';
  res := '<db_tree>\n'; i := 0;
  for select distinct name_part (KEY_TABLE, 0) as TABLE_QUAL from SYS_KEYS
    union select distinct name_part (P_NAME, 0) from SYS_PROCEDURES
    do
    {
       i := i + 1;
       res := concat (res,
                      '<node name="',
                      TABLE_QUAL,
                      '" not-selected-image="images/icons/folder_16.png" selected-image="images/icons/open_16.png" url="" id="',
                      cast (i as varchar),
                      '">\n');
       for select distinct name_part (KEY_TABLE, 1) as TABLE_OWNER
             from SYS_KEYS
             where name_part (KEY_TABLE, 0) = TABLE_QUAL
       union select distinct name_part (P_NAME, 0) from SYS_PROCEDURES
       where name_part (P_NAME, 0) = TABLE_QUAL
       do
         {
	   declare tcnt, pcnt int;
           i := i + 1;

	   whenever not found goto nfc;
	   select count (distinct KEY_TABLE) into tcnt from SYS_KEYS where name_part (KEY_TABLE, 0) = TABLE_QUAL
	       and name_part (KEY_TABLE, 1) = TABLE_OWNER;

	   select count(*) into pcnt from SYS_PROCEDURES where name_part (P_NAME, 0) = TABLE_QUAL
	       and name_part (P_NAME, 1) = TABLE_OWNER;
	   nfc:

           res := concat (res,
                          '\t<node name="',
                          TABLE_OWNER,
                          '"  not-selected-image="images/icons/folder_16.png" selected-image="images/icons/open_16.png" url="" id="',
                          cast (i as varchar),
                          sprintf ('" procs="%d" tables="%d">\n', pcnt, tcnt));


           for select distinct name_part (KEY_TABLE, 2) as TABLE_NAME
             from SYS_KEYS
             where 0 and
                   name_part (KEY_TABLE, 0) = TABLE_QUAL and
                   name_part (KEY_TABLE, 1) = TABLE_OWNER do
             {
               i := i + 1;
               res := concat (res, '\t\t<node name="', TABLE_NAME, '" id="' , cast (i as varchar) , '">\n');
               res := concat (res, '\t\t</node>\n');
             }
           res := concat (res, '\t</node>\n');
         }
       res := concat (res, '</node>\n');
     }
  res := concat (res, '</db_tree>\n');
  set isolation='repeatable';
  return res;
}
;

create procedure db_root_1 (in path varchar)
{
  return xpath_eval ('/db_tree/*', xml_tree_doc (adm_db_tree_1 ()), 0);
}
;

create procedure
adm_db_tree ()
{
  declare ses any;
  declare i int;

  ses := string_output ();
  http ('<db_tree>\n', ses); i := 0;
  for select distinct name_part (KEY_TABLE, 0) as TABLE_QUAL from SYS_KEYS
    union select distinct name_part (P_NAME, 0) from SYS_PROCEDURES
    do
    {
       i := i + 1;
       http (sprintf ('<node name="%V" id="%d">', TABLE_QUAL, i), ses);
         http (sprintf ('<node name="Tables" id="1-%d"/>\n', i), ses);
         http (sprintf ('<node name="Views" id="2-%d"/>\n', i), ses);
         http (sprintf ('<node name="Procedures" id="3-%d"/>\n', i), ses);
         http (sprintf ('<node name="User Defined Types" id="4-%d"/>\n', i), ses);
       http ('</node>\n', ses);
     }
  http ('</db_tree>\n', ses);
  return string_output_string (ses);
}
;

create procedure db_root (in path varchar)
{
  return xpath_eval (sprintf ('/db_tree/*[@name like "%s"]', path), xml_tree_doc (adm_db_tree ()), 0);
}
;

create procedure db_child (in path varchar, in node any)
{
  return xpath_eval (path, node, 0);
}
;

create procedure adm_db_repl_pub_tree()
{
  declare res varchar;
  declare i int;

  res := '<db_tree>\n';
  i := 0;
  for select ACCOUNT from SYS_REPL_ACCOUNTS where SERVER = repl_this_server() and ACCOUNT <> repl_this_server () do
  {
    i := i + 1;
    res := concat(res, '<node name="', ACCOUNT, '" not-selected-image="images/Folder.gif" selected-image="images/open_folder.gif" url="" id="', cast (i as varchar), '">\n');
    i := i + 1;
    res := concat(res, '<node name="', ACCOUNT, '" not-selected-image="images/Folder.gif" selected-image="images/open_folder.gif" url="" id="', cast (i as varchar), '">\n');
    res := concat (res, '</node>\n');
    res := concat (res, '</node>\n');
  }
  res := concat (res, '</db_tree>\n');
  return res;
}
;

create procedure
db_repl_pub_root (in path varchar)
{
  return xpath_eval ('/db_tree/*', xml_tree_doc (adm_db_repl_pub_tree ()), 0);
}
;

create procedure
db_repl_pub_child (in path varchar, in node any)
{
  return xpath_eval (path, node, 0);
}
;

create procedure
adm_exec_stmt_2 (inout control vspx_control, in stmt varchar)
{
  declare stat, msg varchar;
  stat := '00000';
  commit work;
  exec (stmt, stat, msg);
  if (stat <> '00000')
    {
      rollback work;
      control.vc_page.vc_is_valid := 0;
      control.vc_error_message := msg;
      return 0;
    }
  return 1;
}
;

create procedure
adm_uid_to_name (in id int)
{
  declare r varchar;
  whenever not found goto none;
  select U_NAME into r from SYS_USERS where U_ID = id;
  return r;

 none:
  return 'none';
}
;

create procedure
adm_name_to_uid (inout name varchar)
{
  declare i integer;
  whenever not found goto none;
  select U_ID into i from SYS_USERS where U_NAME = name;
  return i;

 none:
  return NULL;
}
;

--
-- Just a mere stub now
--

create procedure
adm_u_is_admin (in uid integer)
{
  if (uid = 1 or uid = 0)
    return 1;
  return 0;
}
;

create procedure
y_sql_user_password (in name varchar)
{
  declare pass varchar;
  pass := NULL;
  whenever not found goto none;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into pass from SYS_USERS where U_NAME = name and U_SQL_ENABLE = 1 and U_IS_ROLE = 0;
none:
  return pass;
}
;

create procedure
y_sql_user_password_check (in name varchar, in pass varchar)
{
  declare nonce, pass1 varchar;
  declare rc int;
  declare ltm datetime;

  nonce := connection_get ('vspx_nonce');
  rc := 0;

  whenever not found goto nfu;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1), U_LOGIN_TIME into pass1, ltm from SYS_USERS where U_NAME = name and
      U_SQL_ENABLE = 1 and U_IS_ROLE = 0;

  --dbg_obj_print ('vspx_nonce', nonce, ' digest:' , pass,' calc: ', md5 (nonce||pass1));

  if (length (nonce) and md5 (nonce||pass1) = pass)
    rc := 1;
  else if (not length (nonce) and pass1 = pass)
    rc := 1;

  if (rc and (ltm is null or ltm < dateadd ('minute', -2, now ())))
    {
      update SYS_USERS set U_LOGIN_TIME = now () where U_NAME = name;
      commit work;
    }

nfu:
  return rc;
}
;

create procedure adm_get_page_name ()
{
  declare path, url, elm varchar;
  declare arr any;
  path := http_path ();
  arr := split_and_decode (path, 0, '\0\0/');
  elm := arr [length (arr) - 1];
  url := xpath_eval ('//*[@url = "'|| elm ||'"]', xml_tree_doc (adm_menu_tree ()));
  if (url is not null or elm = 'error.vspx')
    return elm;
  else
    return '';
}
;

create procedure
space_fmt (in d integer) returns varchar
{
  declare ret float;
  if (d is null or d = 0)
    return 'N/A';
  if (d >= 1024 and d < 1048576)
  {
    ret := cast(d as float)/1024;
    return sprintf('%.2f KB', ret);
  }
  if (d >= 1048576)
  {
    ret := cast(d as float)/1024/1024;
    return sprintf('%.2f MB', ret);
  }
  else
    return sprintf('%d B', d);
}
;

create procedure
space_fmt_long (in d integer) returns varchar
{
  declare ret float;
  if (d is null or d = 0)
    return 'N/A';
  if (d >= 1024 and d < 1048576)
  {
    ret := cast(d as float)/1024;
    return sprintf('%.2f Kbytes', ret);
  }
  if (d >= 1048576)
  {
    ret := cast(d as float)/1024/1024;
    return sprintf('%.2f Mbytes', ret);
  }
  else
    return sprintf('%d bytes', d);
}
;

create procedure
date_fmt (in d datetime) returns varchar
{
  if (d is null)
    return '';
  return yac_hum_datefmt(d);
}
;

create procedure
interval_fmt (in d varchar) returns varchar
{
  return coalesce(cast((select yac_hum_min_to_dur(SE_INTERVAL) from SYS_SCHEDULED_EVENT where SE_NAME = d) as varchar), 'none');
}
;

create procedure
repl_no_fmt (in d any) returns integer
{
  declare _stat, _rno integer;
  repl_status (d[0], d[1], _rno, _stat);
  return _rno;
}
;

create procedure
repl_user_fmt (in d any) returns varchar
{
  declare _sync_user varchar;
  _sync_user := d[2];
  if (repl_is_pushback(d[0], d[1]) = 0)
  {
    if (_sync_user is null or _sync_user = '')
      _sync_user := 'dba';
  }
  else
    _sync_user := 'N/A';
  return _sync_user;
}
;

create procedure
repl_shed_fmt (in d any) returns varchar
{
  declare shed varchar;

  if (repl_is_pushback (d[0], d[1]) = 0)
    {
      shed := cast (coalesce ((select SE_INTERVAL from SYS_SCHEDULED_EVENT where SE_NAME = concat ('repl_', d[0], '_', d[1])), 'No') as varchar);
    }
  else
    shed := 'N/A';

  return shed;
}
;

create procedure
repl_sch_fmt (in d any) returns varchar
{
  declare _stat, _rno integer;
  declare _cstat varchar;

  repl_status (d[0], d[1], _rno, _stat);

  if (_stat = 0)
    _cstat := 'OFF';
  else if (_stat = 1)
    _cstat := 'SYNCING';
  else if (_stat = 2)
    _cstat := 'IN SYNC';
  else if (_stat = 3)
    _cstat := 'REMOTE DISCONNECTED';
  else if (_stat = 4)
    _cstat := 'DISCONNECTED';
  else if (_stat = 5)
    _cstat := 'TO DISCONNECT';

  return _cstat;
}
;

create procedure
cvt_date (in ds varchar)
{
  return cast (ds as datetime);
}
;

create procedure
longstring_fmt (in ls varchar)
{
  declare tmp varchar;
  declare i, l integer;

  if (ls is null)
    return '';

  tmp := '';
  i := 1;

  while (i < length(ls))
    {
      l := 30;

      if ((length(ls) - i) < 30)
        l := length(ls) - i;

      tmp := concat(tmp, substring(ls, i, l));
      tmp := concat(tmp, '\n');

      i := i + 30;
  }

  return tmp;
}
;

create procedure
disk_stat (in par integer)
{
  declare mtd, dta any;
  declare sql_str varchar;

  par := 3;

  -- Temporary patch due to bug #10696, Just removed the where... We'll put it back later
  --if (par = 1)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by KEY_TABLE asc';
  --else if (par = 2)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by INDEX_NAME asc';
  --else if (par = 3)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by TOUCHES desc';
  --else if (par = 4)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by READS asc';
  --else if (par = 5)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by READ_PCT asc';
  --else
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by KEY_TABLE asc';
  if (par = 1)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by KEY_TABLE asc';
  else if (par = 2)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by INDEX_NAME asc';
  else if (par = 3)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by TOUCHES desc';
  else if (par = 4)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by READS asc';
  else if (par = 5)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by READ_PCT asc';
  else
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by KEY_TABLE asc';

  exec (sql_str, null, null, vector (), 0, mtd, dta);
  return dta;
}
;

create procedure
disk_stat_meta(in par integer)
{
  declare mtd, dta any;
  declare sql_str varchar;
    par := 3;

  -- Temporary patch due to bug #10696, Just removed the where... We'll put it back later
  --if (par = 1)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by KEY_TABLE asc';
  --else if (par = 2)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by INDEX_NAME asc';
  --else if (par = 3)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by TOUCHES desc';
  --else if (par = 4)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by READS asc';
  --else if (par = 5)
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by READ_PCT asc';
  --else
  --  sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT where READS > 0 order by KEY_TABLE asc';
  if (par = 1)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by KEY_TABLE asc';
  else if (par = 2)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by INDEX_NAME asc';
  else if (par = 3)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by TOUCHES desc';
  else if (par = 4)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by READS asc';
  else if (par = 5)
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by READ_PCT asc';
  else
    sql_str := 'select KEY_TABLE, INDEX_NAME, TOUCHES, READS, READ_PCT from DB.DBA.SYS_D_STAT order by KEY_TABLE asc';
  exec (sql_str, null, null, vector (), -1, mtd, dta );
  return mtd[0];
}
;

create procedure
adm_next_checkbox (in keyw varchar, inout params varchar, inout spos integer)
{
  declare pos integer;
  declare len integer;
  declare klen integer;
  declare s varchar;

  len := length (params);
  klen := length (keyw);

  while (spos < len)
    {
      s := aref (params, spos);
      if (keyw = "LEFT" (s, klen) and
    'on' = lcase (coalesce (aref (params, spos + 1),'')))
  {
    spos := spos + 2;
    return "RIGHT" (s, length (s) - klen);
  }
      spos := spos + 2;
    }
}
;

create procedure
adm_get_file_dsn ()
{
  declare idx, len integer;
  declare name, s_root varchar;
  declare ret, _all any;
  declare _err_code, _err_message varchar;
  declare exit handler for sqlstate '*'
    {
      _err_code := __SQL_STATE; _err_message := __SQL_MESSAGE; goto error;
    };

  _all := sys_dirlist ('.', 1);
  s_root := server_root ();

  idx := 0;
  len := length (_all);
  ret := vector ();

  while (idx < len)
    {
       name := aref (_all, idx);

       if (strstr (name, '.dsn'))
         ret := vector_concat (ret, vector (concat (s_root, name)));

       idx := idx + 1;
    }

  return ret;

error:
  return vector ();
}
;

create procedure
adm_lt_dsn_options (in dsn varchar)
{
  declare dsns, f_dsns any;
  declare len, len_f, idx integer;

  dsns := sql_data_sources(1);

  idx := 0;
  len := length (dsns);
  len_f := 0;

  if (sys_stat('st_build_opsys_id') = 'Win32')
    {
       f_dsns := adm_get_file_dsn ();
       len_f := length (f_dsns);
    }

  if (len = 0 and len_f = 0)
    {
      http('<option value=NONE>No pre-defined DSNs</option>');
    }
  else
    {
      while (idx < len)
  {
    http (sprintf ('<option value="%s" %s>%s</option>' ,
       aref (aref (dsns, idx), 0),
       select_if (aref (aref (dsns, idx), 0), dsn),
       aref (aref ( dsns, idx), 0)));
    idx := idx + 1;
  }

      if (sys_stat('st_build_opsys_id') = 'Win32' and len_f > 0)
  {
    idx := 0;
    while (idx < len_f)
      {
        http (sprintf ('<option value="%s" %s>%s</option>' ,
           aref (f_dsns, idx), select_if (aref (f_dsns, idx), dsn),
           aref (f_dsns, idx)));
        idx := idx + 1;
      }
  }
    }
}
;

create procedure
true_if (in sel varchar, in val varchar)
{
  if (sel = val)
      return ('true');
  return ('false');
}
;

create procedure
make_full_name (in cat varchar, in sch varchar, in name varchar, in quoted integer := 0)
returns varchar
{
    declare ret, quote varchar;
    if (quoted <> 0) quote := '"';
    else quote := '';

    ret := '';

    if (length (cat)) ret := concat (quote, replace (cat, '.', '\x0A'), quote, '.');
    if (length (sch)) ret := concat (ret, quote, replace (sch, '.', '\x0A'), quote);
    if (length (ret))  ret := concat (ret, '.');
    if (length (name))
      ret := concat (ret, quote, replace (name, '.', '\x0A'), quote);
    return ret;
}
;

create procedure
adm_lt_make_dsn_part (in dsn varchar)
{
  declare inx, c integer;
  dsn := ucase (dsn);
  inx :=0;
  while (inx < length (dsn)) {
    c := aref (dsn, inx);
    if (not ((c >= aref ('A', 0) and c <= aref ('Z', 0))
       or (c >= aref ('0', 0) and c <= aref ('9', 0))))
      aset (dsn, inx, aref ('_', 0));
    inx := inx + 1;
  }
  return dsn;
}
;

create procedure
adm_make_option_list (in opts any, in name varchar, in val varchar, in spare integer)
{
  declare i, l, j, k integer;
  declare ch varchar;
  l := length (opts); i := 0;
  j := 0; k := 1;
  if (spare > 0) {
      j := 1;
      k := 2;
  }
  http (sprintf ('<select name="%s">', name));
  while (i < l) {
      ch := '';
      if (opts[i] = val)
  ch := 'selected="true"';
      http (sprintf ('<option value="%s" %s>%s</option>', opts[i+j], ch, opts[i]));
      i := i + k;
  }
  http ('</select>');
}
;

create procedure
adm_lt_getRPKeys2 (in dsn varchar,
                   in tbl_qual varchar,
                   in tbl_user varchar,
                   in tbl_name varchar)
{
  declare pkeys, pkey_curr, pkey_col, my_pkeys any;
  declare pkeys_len, idx integer;

  if (length (tbl_qual) = 0)
    tbl_qual := NULL;
  if (length (tbl_user) = 0)
    tbl_user := NULL;

  if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
    {
      declare exit handler for SQLSTATE '*'
        goto next;
--dbg_printf ('Calling sql_primary_keys:\ndsn: %s, tbl_qual: %s, tbl_user: %s, tbl_name: %s',
--            dsn, tbl_qual, tbl_user, tbl_name);
      pkeys := sql_primary_keys (dsn, tbl_qual, tbl_user, tbl_name);
    };
next:

  if (not pkeys) pkeys := NULL;

  pkeys_len := length (pkeys);
  idx := 0;
  my_pkeys := vector();
  if (0 <> pkeys_len)
    {
      while (idx < pkeys_len)
      {
  pkey_curr := aref (pkeys, idx);
  pkey_col := aref (pkey_curr, 3);
  my_pkeys := vector_concat (my_pkeys, vector(pkey_col));
  idx := idx +1;
      }
    }
  else
    {
      declare inx_name varchar;
      inx_name := null;
      if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
        {
           declare exit handler for SQLSTATE '*'
             goto next2;

           pkeys := sql_statistics (dsn, tbl_qual, tbl_user, tbl_name, 0, 1);
        };
      next2:

      if (not pkeys) pkeys := NULL;

      pkeys_len := length (pkeys);

      if (0 <> pkeys_len)
  {
    while (idx < pkeys_len)
    {
      pkey_curr := aref (pkeys, idx);
	       if (inx_name is null)
	         inx_name := pkey_curr[5];
	       --dbg_obj_print (inx_name, pkey_curr[5]);
	       if (inx_name <> pkey_curr[5])
	         goto pk_end;
      pkey_col := aref (pkey_curr, 8);
            if (pkey_col is not null)
        my_pkeys := vector_concat (my_pkeys, vector(pkey_col));
      idx := idx +1;
    }
	  pk_end:;
  }
      else
  {
    pkeys := NULL;
    pkeys_len := 0;
  }
    }
  --dbg_obj_print (my_pkeys);
  return my_pkeys;
}
;

create procedure
vector_print (in in_vector any)
{
  declare len, idx integer;
  declare temp varchar;
  declare res varchar;

  if (isstring (in_vector))
    in_vector := vector (in_vector);

  len := length (in_vector);
  res:='';
  idx := 0;
  while ( idx < len ) {
    if (idx > 0 )
      res := concat (res, ', ');
    temp := aref (in_vector, idx);
    if (__tag(temp) = 193)
      res := concat (res, 'vector');
    else
      res := concat (res, temp);
    idx := idx+1;
  }
  return (res);
}
;

/*
   VDB table/view linking
 */
create procedure
vdb_link_tables (in pref any,
         in params any,
                 in ds_name varchar,
                 in tables any,
                 in keys any,
     inout errs any)
{
  declare sql_stt, sql_msg, sql_stt1, sql_msg1 varchar;
  declare i, n integer;
  declare tbl_qual, tbl_user, tbl_name, rname varchar;
  declare n_qual, n_user, n_name,  lname varchar;
  declare tbl_key any;
  declare _r_tbl, _l_tbl any;

  sql_stt := ''; sql_msg := ''; sql_stt1 := ''; sql_msg1 := '';

  i := 0;
  n := length (tables);

  while (i < n)
    {
      _r_tbl := aref (aref (tables, i), 0);
      _l_tbl := aref (aref (tables, i), 1);

      --dbg_printf ('i: %d', i);
      --dbg_printf ('table #%d:%s.%s.%s', i+1, _r_tbl[0], _r_tbl[1], _r_tbl[2]);

      tbl_key := aref (keys, i);

      --dbg_obj_print ('tbl_key:', tbl_key);

      if (length (tbl_key) = 0) tbl_key := NULL;

--          {
--            dbg_printf ('No keys defined');
--            err_messages := vector_concat (err_messages,
--                                           vector ('Primary key definition is required.'));
--            goto error;
--          }

      tbl_qual := aref (_r_tbl, 0);
      tbl_user := aref (_r_tbl, 1);
      tbl_name := aref (_r_tbl, 2);
      rname := make_full_name (null, tbl_user, tbl_name);

      n_qual := get_keyword (sprintf ('%s_catalog_%d', pref, i), params, '');
      n_user := get_keyword (sprintf ('%s_schema_%d', pref, i), params, '');
      n_name := get_keyword (sprintf ('%s_name_%d', pref, i), params, '');

      --dbg_printf ('local  :%s.%s.%s', n_qual, n_user, n_name);
      --dbg_obj_print (n_qual,n_user,n_name, rname);

      if (n_qual = '' or n_user = '' or n_name = '')
        {
    errs := vector_concat (errs, vector (vector (rname, '22023', 'Catalog, Schema and Name fields should not be empty.')));
          goto error;
        }

      lname := make_full_name (n_qual, n_user, n_name);
      if (exists (select RT_NAME from DB.DBA.SYS_REMOTE_TABLE where RT_NAME = lname))
        {
    errs := vector_concat (errs, vector (vector (rname, '22023', 'Table is already linked.')));
          goto error;
        }

      sql_stt := '00000';
      sql_stt1 := '00000';
      sql_msg := '';

      --dbg_printf ('Attaching.');

      exec ('DB.DBA.vd_attach_view (?, ?, ?, ?, ?, ?, 1)',
              sql_stt,
              sql_msg,
              vector (ds_name, rname, lname, NULL, NULL, tbl_key),
              0, NULL, NULL);

       if (sql_stt <> '00000')
         {
           rollback work;
           errs := vector_concat (errs, vector (vector (rname, sql_stt, sql_msg)));
           goto error;
         }
       exec ('commit work', sql_stt1, sql_msg);
       if (sql_stt1 <> '00000')
         {
     rollback work;
     errs := vector_concat (errs, vector (vector (rname, sql_stt, sql_msg)));
           goto error;
         }

     error:
      i := i + 1;
    }
}
;

create procedure
vdb_link_procedures (in params any,
                     in ds_name varchar,
                     in procs any,
                     inout errs any)
{
  declare i, l, j, m integer;
  declare pro, lname, lname1, stmt, st, msg varchar;

  j := 0; m := length(procs);
  while (j < m)
    {
      declare pars any;
      declare q,o,n, par, typ varchar;
      declare q1,o1,n1, cmn1 varchar;
      declare meta any;
      declare _comment varchar;
      declare att_type varchar;

      meta := vector ();
      lname := sprintf ('%s.%s.%s', aref (procs, j + 1), aref (procs, j + 2), aref (procs, j + 3));
      lname1 := sprintf ('"%I"."%I"."%I"', aref (procs, j + 1), aref (procs, j + 2), aref (procs, j + 3));

      att_type := aref (procs, j + 4);
      _comment := aref (procs, j + 5);

      if (__proc_exists (lname))
        {
          errs := vector_concat (errs, vector (vector (procs[j], '22023', 'Procedure already linked.')));
          goto error;
        }

      q := name_part (procs[j], 0);
      o := name_part (procs[j], 1);
      n := name_part (procs[j], 2);

      if (q <> '')
        stmt := sprintf ('attach procedure "%I"."%I"."%I" (', q, o, n);
      else
        stmt := sprintf ('attach procedure "%I"."%I" (', o, n);

      pars := aref (procs, j + 6);

      --dbg_obj_print ('PARS', pars);

      declare br integer;

      i := 0; l := length (pars); br := 0;

      while (i < l)
        {
          declare t, na, dt, st, t1 varchar;
          t1 := '';

          if (not isarray (pars[i]))
          goto nexti;

          t  := pars[i][0];
          na := pars[i][1];
          dt := pars[i][2];
          st := pars[i][3];

        --if (t = 'UNDEFINED')

          t1 := get_keyword (sprintf ('parm_%d_%s_io',i, na), params, '');

          if (t1 <> '')
            t := t1;

          meta := vector_concat (meta, vector (vector (t, concat('"',na,'"'), dt, st)));

          if (t = 'RESULTSET')
              goto nexti;

          if (t = 'RETURNS')
            {
              stmt := concat (trim (stmt, ', '), ') RETURNS ', dt);
              br := 1;
            }

          else
            if (t <> 'RESULTSET')
              stmt := concat (stmt, t, ' ', na, ' ', dt);

          if (st <> '')
              stmt := concat (stmt, ' __soap_type ''', st, '''');

          stmt := concat (stmt, ',');
         nexti:
          i := i + 1;
        }

      stmt := trim (stmt, ', ');

      if (not br)
        stmt := concat (stmt, ')');

      stmt := concat (stmt, sprintf (' as %s from ''%s''', lname1, ds_name));


          -- here we are ready to attach

      if (att_type = 'wrap' or att_type = 'rset')
        {
          declare make_resultset integer;

          if (att_type = 'rset')
            make_resultset := 1;
          else
            make_resultset := 0;

          st := '00000';
          vd_remote_proc_wrapper (ds_name,
                                  aref (procs, j),
                                  lname,
                                  meta,
                                  st,
                                  msg,
                                  make_resultset,
                                  _comment);
        }
      else
        {
          st := '00000';
          exec (stmt, st, msg);
          --dbg_obj_print('REMOTE PROCEDURE attach', stmt);
        }

      if (st <> '00000')
        {
          errs := vector_concat (errs, vector (vector (procs[j], st, msg)));
          goto error;
        }

     error:
      j := j + 7;
    }
}
;

sequence_set ('dbpump_temp', 0, 0)
;

sequence_set ('dbpump_id', 1, 0)
;

create procedure "PUMP"."DBA"."__GET_TEMPORARY" (  )
{
  return  sprintf('./tmp/dbpump%d.tmp', sequence_next('dbpump_temp'));
}
;

create procedure "PUMP"."DBA"."__GET_KEYWORD" ( in name varchar, in arr any, in def varchar )
{
  if (arr is not null)
    return get_keyword(name,arr,def);
  return '';
}
;

create procedure "PUMP"."DBA"."URLIFY_STRING" (in val varchar)
{
  declare i,n,c integer;
  declare s varchar;
  s := '';
  if (val is not null and length(val)>0) {
      n := length(val);
      i := 0;
      while (i<n) {
          c := aref(val,i);
          if (c = 32)
              s := concat(s,'+');
          else {
              if ((c>=48 and c<=57) or (c>=97 and c<=122) or (c>=65 and c<=90))
                  s := concat(s,sprintf('%c',c));
              else
                  s := concat(s,sprintf('%%%02X',c));
          }
          i := i + 1;
      }
  }
  return s;
}
;

create procedure "PUMP"."DBA"."DBPUMP_START_COMPONENT" (  in pars any,
              in name varchar,
              in arg varchar )
{
  declare i,n integer;
  declare str,allt,s,argsfile varchar;
  declare outarr any;

  allt := 'all_together_now';
  argsfile := sprintf('./tmp/%s.cmd-line',name);
  if (arg is null or length(arg)=0)
    arg := 'DUMMY';
  str := sprintf('%s %s ', name, arg);
  n := length(pars);
  str := concat (str, sprintf (' %s=%s ', allt,
  "PUMP"."DBA"."URLIFY_STRING" (
    "PUMP"."DBA"."__GET_KEYWORD" (allt,pars,''))));
  i := n - 2;
  while (i>=0)
  {
    s := aref(pars,i);
    if (neq (allt, s))
      str := concat (str, sprintf (' %s=%s ', s,"PUMP"."DBA"."URLIFY_STRING" (aref(pars,i+1))));
    i := i - 2;
  }
  string_to_file (argsfile,str,-2);
  str := sprintf ('@%s', argsfile);
--  str := concat (str, ' > ');
--  str := concat (str, tmp);
  commit work;
  run_executable ('dbpump', 1, str);
  return str;
}
;

create procedure "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (  inout pars any,
              in name varchar,
              in arg varchar,
              in outerr integer := 1 )
{
  declare i,n integer;
  declare str,allt,s,argsfile varchar;
  declare tmp,errstr varchar;
  declare outarr any;

  allt := 'all_together_now';
  tmp := "PUMP"."DBA"."__GET_TEMPORARY" ();
  argsfile := sprintf('./tmp/%s.cmd-line',name);
  if (arg is null or length(arg)=0)
    arg := 'DUMMY';
  str := sprintf('%s %s %s', name, arg, tmp);
  n := length(pars);
  str := concat (str, sprintf (' %s=%s ', allt,
  "PUMP"."DBA"."URLIFY_STRING" (
    "PUMP"."DBA"."__GET_KEYWORD" (allt,pars,''))));
  i := n - 2;
  while (i>=0)
  {
    s := aref(pars,i);
    if (neq (allt, s))
      str := concat (str, sprintf (' %s=%s ', s,"PUMP"."DBA"."URLIFY_STRING" (aref(pars,i+1))));
    i := i - 2;
  }

  declare exit handler for sqlstate '*' { errstr := sprintf ('Temporary file creation error:\n%s %s\nprobably permissions were revoked for temporary folder\nor it doesn\'t exist', __SQL_STATE, __SQL_MESSAGE); goto error_gen; };

  string_to_file(argsfile,str,-2);
  str := sprintf ('@%s', argsfile);
--  str := concat (str, ' > ');
--  str := concat (str, tmp);
  commit work;
  declare exit handler for sqlstate '*' { errstr := sprintf ('Dbpump running error:\n%s %s\nProbably the executable \'dbpump\' doesn\'t exist in \'bin\' folder', __SQL_STATE, __SQL_MESSAGE); goto error_gen; };
  run_executable('dbpump', 1, str);
  declare str varchar;

  declare exit handler for sqlstate '*' { errstr := sprintf ('Results obtaining error:\n%s %s\nProbably the executable \'dbpump\' crashed during the work', __SQL_STATE, __SQL_MESSAGE); goto error_gen; };
  str := file_to_string(tmp);
  string_to_file(sprintf('./tmp/%s.cmd-out',name),str,-2);
  "PUMP"."DBA"."DBPUMP_START_COMPONENT" (pars, 'remove_temporary', tmp);
--  run_executable('rm',0,'-f',tmp);
  return str;

error_gen:
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'last_error', errstr);
  if (outerr)
    return sprintf ('last_error=%s', errstr);
  else
    return '';
}
;


create procedure "PUMP"."DBA"."HTML_RETRIEVE_TABLES" (  inout arr any )
{
  declare str varchar;
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (arr,'retrieve_tables','*');
  if (str is null)
    return '';
  return str;
}
;

create procedure "PUMP"."DBA"."HTML_RETRIEVE_QUALIFIERS_VIA_PLSQL" ( in arr any )
{
  declare str, s varchar;
  str := '%=None&custom=Advanced';
whenever not found goto fin;

  for (select distinct name_part (KEY_TABLE, 0, 'DB') as qual from DB.DBA.SYS_KEYS) do
    {
      str := concat (str, '&', qual, '=', qual);
    }
fin:
  return str;
}
;


create procedure "PUMP"."DBA"."RETRIEVE_TABLES_VIA_PLSQL" ( in qual_mask varchar, in owner_mask varchar, in table_mask varchar, in out_type integer := 1 )
{

  declare str, s varchar;
  declare first integer;

  first := 1;
  str := '';
  whenever not found goto fin;
  for( select
           name_part("KEY_TABLE",0) as t_qualifier,
           name_part("KEY_TABLE",1) as t_owner,
           name_part("KEY_TABLE",2) as t_name,
           table_type("KEY_TABLE")  as t_type
         from DB.DBA.SYS_KEYS
         where
           __any_grants ("KEY_TABLE") and
           name_part("KEY_TABLE",0) like qual_mask and
           name_part("KEY_TABLE",1) like owner_mask and
           name_part("KEY_TABLE",2) like table_mask and
           table_type("KEY_TABLE") = 'TABLE' and
           KEY_IS_MAIN = 1 and
           KEY_MIGRATE_TO is NULL
           order by "KEY_TABLE") do {
      if (not first) {
        if (out_type = 1)
          str := concat (str, '&');
        else if (out_type = 2)
          str := concat (str, '@');
      }
      s := concat (t_qualifier, '.', t_owner, '.', t_name);
      if (out_type = 1)
        str := concat (str, s, '=', s);
      else if (out_type = 2)
        str := concat (str, s);
      first := 0;
  }
fin:
  return str;
}
;

create procedure "PUMP"."DBA"."GET_DSN" () returns varchar
{
  declare port, sect, item varchar;
  declare nitems integer;
  port := '1111';
  sect := 'Parameters';
  nitems := cfg_item_count(virtuoso_ini_path(), sect);

  while ( nitems >= 0 ) {
    item := cfg_item_name(virtuoso_ini_path(), sect, nitems);
    if (equ(item,'ServerPort')) {
      port := cfg_item_value(virtuoso_ini_path(), sect, item);
      goto next;
    }
    nitems := nitems - 1;
  }
next:
  return concat('localhost:',port);
}
;

create procedure "PUMP"."DBA"."GET_USER" () returns varchar
{
  declare auth varchar;
  declare _user varchar;
  declare _pwd varchar;
  --sql_user_password (in name varchar)
  --auth  := db.dba.vsp_auth_vec (lines);
  --_user := get_keyword ('username', auth, '');
--  _pwd  := get_keyword ('pass', auth, '');
  _user := connection_get('vspx_user');
  return _user;
}
;

create procedure "DB"."DBA"."BACKUP_VIA_DBPUMP" (
                        in username varchar,
                        in passwd varchar,
                        in datasource varchar,
                        in dump_path varchar,
                        in dump_dir varchar,
                        in out_fmt integer,
                        in dump_items varchar,
                        in ins_mode integer,
                        in chqual varchar,
                        in chuser varchar,
                        in sel_tables varchar
                          ) returns varchar
{
  declare pars, res any;
  pars:= null;

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'user', username);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'password', passwd);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'datasource', datasource);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_path', dump_path);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_dir', dump_dir);

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'table_defs', case dump_items[0] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'table_data', case dump_items[1] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'triggers', case dump_items[2] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'stored_procs', case dump_items[3] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'constraints', case dump_items[4] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'fkconstraints', case dump_items[5] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'views', case dump_items[6] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'users', case dump_items[7] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'grants', case dump_items[8] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'text_flag', case out_fmt when 1 then 'Binary' else 'SQL' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'insert_mode', chr(ins_mode + ascii('1')));
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'change_qualifier', case when length(chqual) > 0 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'new_qualifier', chqual );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'change_owner', case when length(chuser) > 0 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'new_owner', chuser );

/*
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'custom_qual', '1');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'qualifier_mask', '%');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'owner_mask', '%');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'tabname', '%');
*/

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'choice_sav',  sel_tables);
  res := "PUMP"."DBA"."DUMP_TABLES_AND_PARS_RETRIEVE" (pars);

  declare str varchar;
  str := get_keyword ('result_txt', res, NULL);
  if(str is null)
    str := get_keyword ('last_error', res, '');

  return str;
}
;

create procedure "PUMP"."DBA"."DUMP_TABLES_AND_PARS_RETRIEVE" ( inout pars any )
{
  declare n integer;
  declare str varchar;
  declare outarr any;

--  checkpoint;
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (pars,'dump_tables','*');
  outarr := split_and_decode(str,0);
--  n := length(outarr);
  return outarr;
}
;

--drop procedure restore_tables_and_pars_retrieve;
create procedure "PUMP"."DBA"."RESTORE_TABLES_AND_PARS_RETRIEVE" ( inout pars any )
{
  declare n integer;
  declare str varchar;
  declare outarr any;

--  checkpoint;

  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (pars,'restore_tables','*');
  outarr := split_and_decode(str,0);
--  n := length(outarr);
  return outarr;
}
;

create procedure "DB"."DBA"."RESTORE_DBPUMP'S_FOLDER" (
                        in username varchar,
                        in passwd varchar,
                        in datasource varchar,
                        in dump_path varchar,
                        in dump_dir varchar,
                        in dump_items varchar,
                        in chqual varchar,
                        in chuser varchar
                        ) returns varchar
{
  declare pars, res any;
  pars:= null;

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'user', username);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'password', passwd);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'datasource', datasource);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_path', dump_path);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_dir', dump_dir);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'restore_users', case dump_items[7] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'restore_grants', case dump_items[8] when 1 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'change_rqualifier', case when length(chqual) > 0 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'new_rqualifier', chqual );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'change_rowner', case when length(chuser) > 0 then 'on' else 'off' end );
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'new_rowner', chuser );
  res := "PUMP"."DBA"."RESTORE_TABLES_AND_PARS_RETRIEVE" (pars);
  declare str varchar;
  str := get_keyword ('result_txt', res, NULL);
  if(str is null)
    str := get_keyword ('last_error', res, '');

  return str;
}
;

--drop procedure html_choice_rpath;
create procedure "PUMP"."DBA"."DBPUMP_CHOICE_RPATH"( in path varchar := './backup' ) returns any
{
  declare str varchar;
  declare outarr any;
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" ( vector(), 'choice_rpath', path, 0);
  outarr := split_and_decode(str,0);
  return outarr;
}
;

create procedure "PUMP"."DBA"."DBPUMP_CHOICE_RSCHEMA" ( in path varchar := './backup' ) returns any
{
  declare str varchar;
  declare pars any;
  declare outarr any;
  pars:= null;
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'show_content', '6');
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (pars,'choice_rschema',path, 0);
  outarr := split_and_decode(str,0);
  return outarr;
}
;

create procedure check_grants(in user_name  varchar, in role_name varchar) {
  declare user_id, group_id, role_id, sql_enabled, dav_enabled integer;
  whenever not found goto nf;
  if (user_name='') return 0;
  select U_ID, U_GROUP into user_id, group_id from SYS_USERS where U_NAME=user_name;
  if (user_id = 0 OR group_id = 0)
    return 1;
  if (role_name is null or role_name = '')
    return 0;

  select U_ID into role_id from SYS_USERS where U_NAME=role_name;
  if (exists(select 1 from SYS_ROLE_GRANTS where GI_SUPER=user_id and GI_SUB=role_id))
      return 1;
nf:
  return 0;
}
;

create procedure create_inifile_page(in section varchar, in rel_path varchar, in file varchar, in is_dav integer)
{
  declare xslt_uri, src_uri, res, path  varchar;
  declare src_tree, pars any;
  declare vspx any;
  if (is_dav = 0)
  {
    xslt_uri := concat ('file://', rel_path, '/inifile_style.xsl');
    src_uri := concat ('file://', rel_path, '/inifile_metadata.xml');
  }
  else
  {
    xslt_uri := concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', rel_path, '/inifile_style.xsl');
    src_uri := concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:', rel_path, '/inifile_metadata.xml');
  }
  src_tree := xtree_doc (XML_URI_GET_STRING ('', src_uri));
  vspx := string_output();
  pars := vector('section_name', section);
  res := xslt(xslt_uri, src_tree, pars);
  http_value(res, 0, vspx);
  if (is_dav = 0)
    string_to_file(concat(path,'/', rel_path, '/',file),string_output_string(vspx),-2);
  else
    DAV_RES_UPLOAD(concat(rel_path, '/', file), string_output_string(vspx), '', '111101101R', 'dav', 'administrators', 'dav');
}
;

create procedure get_ini_location() {
   declare num, pos integer;
   declare fpath, res varchar;
   res:='';
  fpath:= virtuoso_ini_path();
 pos:=0;
 while((num:=locate('/',fpath,pos+1)) > 0)
  pos:=num;

 if (pos=0 )  {
   while( (num:=locate('\\',fpath,pos+1)) > 0)
        pos:=num;
 }


 if (pos > 0)
   res:=substring(fpath,1,pos);

 return res;
}
;

create procedure column_is_pk( in tablename varchar, in colname varchar ) returns integer
{
  if (exists( select 1 from DB.DBA.SYS_KEYS v1, DB.DBA.SYS_KEYS v2, DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS
              where upper(v1.KEY_TABLE) = upper(tablename) and upper("DB"."DBA"."SYS_COLS"."COLUMN") = upper(colname)
                    and v1.KEY_IS_MAIN = 1 and v1.KEY_MIGRATE_TO is NULL
                    and v1.KEY_SUPER_ID = v2.KEY_ID
                    and kp.KP_KEY_ID = v1.KEY_ID
                    and kp.KP_NTH < v1.KEY_DECL_PARTS
                    and DB.DBA.SYS_COLS.COL_ID = kp.KP_COL
                    and "DB"."DBA"."SYS_COLS"."COLUMN" <> '_IDN' )
    )
    return 1;
  else
    return 0;
}
;

create procedure column_is_fk( in tablename varchar, in colname varchar ) returns integer
{
  if (exists( select 1 from DB.DBA.SYS_FOREIGN_KEYS as SYS_FOREIGN_KEYS
              where upper(FK_TABLE) = upper(tablename) and upper(FKCOLUMN_NAME) = upper(colname))
    )
    return 1;
  else
    return 0;
}
;

create procedure create_table_sql( in tablename varchar, in constr int := 1) returns varchar
{
  declare sql, pks, fks, full_tablename varchar;
  declare k integer;
  full_tablename := make_full_name ( name_part(tablename,0), name_part(tablename,1), name_part(tablename,2), 1 );
  sql := concat('create table ', full_tablename, '\n(');
  pks := '';
  fks := '';
  k := 0;

    for SELECT c."COLUMN" as COL_NAME, dv_type_title (c."COL_DTP") as COL_TYPE, c."COL_PREC" as "COL_PREC",
           c."COL_SCALE" as "COL_SCALE", c."COL_NULLABLE" as "COL_NULLABLE", c.COL_CHECK as COL_CHECK
      from  DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, "SYS_COLS" c
      where
            name_part (k.KEY_TABLE, 0) =  name_part (tablename, 0) and
            name_part (k.KEY_TABLE, 1) =  name_part (tablename, 1) and
            name_part (k.KEY_TABLE, 2) =  name_part (tablename, 2)
            and __any_grants (k.KEY_TABLE)
        and c."COLUMN" <> '_IDN'
        and k.KEY_IS_MAIN = 1
        and k.KEY_MIGRATE_TO is null
        and kp.KP_KEY_ID = k.KEY_ID
        and c.COL_ID = kp.KP_COL
	order by kp.KP_COL do {


      if (k > 0 )
          sql := concat( sql, ',' );
      else k := 1;

      sql := concat( sql, '\n  "', COL_NAME,  '" ', COL_TYPE );
      if(COL_TYPE = 'VARCHAR' and COL_PREC > 0)
        sql := sprintf( '%s(%d)', sql, COL_PREC );

      if (strchr (coalesce (COL_CHECK, ''), 'I') is not null)
	sql := sql ||' IDENTITY';

      if (column_is_pk(tablename, COL_NAME) = 1 ) {
        if (length(pks) > 0 )
          pks := concat( pks, ', "', COL_NAME,  '"' );
        else
          pks := concat( '"', COL_NAME,  '"' );
      }
  }
  if (pks <> '' ) {
    sql := concat(sql, ',\n  PRIMARY KEY (', pks, ')');
  }
  sql := concat(sql, '\n);');

  if (not constr)
    goto endt;

  for select PK_TABLE,
       FK_NAME,
       trim(yac_agg_concat('"' || PKCOLUMN_NAME || '"',', '),' ,') PKCOLUMNS,
       trim(yac_agg_concat('"' || FKCOLUMN_NAME || '"',', '),' ,') FKCOLUMNS,
       UPDATE_RULE,DELETE_RULE
      from DB.DBA.SYS_FOREIGN_KEYS as SYS_FOREIGN_KEYS
      where upper(FK_TABLE) = upper(tablename)
      group by PK_TABLE, FK_NAME, UPDATE_RULE, DELETE_RULE do {

      declare PKTABLE_NAME varchar;
      PKTABLE_NAME := make_full_name ( name_part(PK_TABLE,0), name_part(PK_TABLE,1), name_part(PK_TABLE,2), 1);

      fks := concat(fks, '\nALTER TABLE ', full_tablename, '\n');
      fks := concat(fks, '  ADD CONSTRAINT "',FK_NAME,'" FOREIGN KEY (', FKCOLUMNS, ')\n');
      fks := concat(fks, '    REFERENCES ', PKTABLE_NAME, ' (', PKCOLUMNS, ')');
      if (UPDATE_RULE = 1)
        fks := concat(fks, ' ON UPDATE CASCADE');
      else if (UPDATE_RULE = 2)
        fks := concat(fks, ' ON UPDATE SET NULL');
      else if (UPDATE_RULE = 3)
        fks := concat(fks, ' ON UPDATE SET DEFAULT');
      if (DELETE_RULE = 1)
        fks := concat(fks, ' ON DELETE CASCADE');
      else if (DELETE_RULE = 2)
        fks := concat(fks, ' ON DELETE SET NULL');
      else if (DELETE_RULE = 3)
        fks := concat(fks, ' ON DELETE SET DEFAULT');
      fks := concat(fks,';\n' );
  }

  for select C_TEXT,sql_text(deserialize(blob_to_string(C_MODE))) SQL_TEXT
        from DB.DBA.SYS_CONSTRAINTS
       where upper(C_TABLE) = upper(tablename) do {
      fks := concat(fks, '\nALTER TABLE ', full_tablename, '\n');
      fks := concat(fks, '  ADD', either(equ(C_TEXT,'0'),'',concat(' CONSTRAINT "',C_TEXT,'"\n   ')));
      fks := concat(fks, ' CHECK (', SQL_TEXT, ');\n' );
  }

  if (fks <> '' ) {
    sql := concat(sql, '\n', fks);
  }

  endt:

  return sql;
}
;

yacutia_exec_no_error('drop view db.dba.sql_statistics')
;

create view db.dba.sql_statistics as
  select
    iszero(SYS_KEYS.KEY_IS_UNIQUE) AS NON_UNIQUE SMALLINT,
    SYS_KEYS.KEY_TABLE AS TABLE_NAME VARCHAR(128),
    name_part (SYS_KEYS.KEY_TABLE, 0) AS INDEX_QUALIFIER VARCHAR(128),
    name_part (SYS_KEYS.KEY_NAME, 2) AS INDEX_NAME VARCHAR(128),
    ((SYS_KEYS.KEY_IS_OBJECT_ID*8) +
     (3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS INDEX_TYPE SMALLINT,
    (SYS_KEY_PARTS.KP_NTH+1) AS SEQ_IN_INDEX SMALLINT,
    "SYS_COLS"."COLUMN" AS COLUMN_NAME VARCHAR(128)
  from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS, DB.DBA.SYS_COLS SYS_COLS
  where SYS_KEYS.KEY_IS_MAIN = 0 and SYS_KEYS.KEY_MIGRATE_TO is NULL
    and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID
    and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS
    and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL
    and "SYS_COLS"."COLUMN" <> '_IDN'
  order by SYS_KEYS.KEY_TABLE, SYS_KEYS.KEY_NAME, SYS_KEY_PARTS.KP_NTH
;

create procedure db.dba.sql_table_indexes( in tablename varchar )
{
  declare cols varchar;
  declare TABLE_NAME, INDEX_NAME, COLUMNS varchar;
  declare NON_UNIQUE, INDEX_TYPE integer;

  if (tablename is null)
    tablename := '%';

  result_names(TABLE_NAME, INDEX_NAME, NON_UNIQUE, INDEX_TYPE, COLUMNS);

  for ( select TABLE_NAME as TABLE_N, INDEX_NAME as INDEX_N, NON_UNIQUE, INDEX_TYPE
      from db.dba.sql_statistics
      where upper(TABLE_NAME) like upper(tablename)
      group by TABLE_NAME, INDEX_NAME, NON_UNIQUE, INDEX_TYPE
      order by 1, 2 )
  do {
    cols := '';
    for ( select COLUMN_NAME from db.dba.sql_statistics as ss
          where ss.TABLE_NAME = TABLE_N and ss.INDEX_NAME = INDEX_N )
    do {
      if(cols='')
        cols := COLUMN_NAME;
      else
        cols := concat(cols, ', ', COLUMN_NAME);
    };
    result(TABLE_N, INDEX_N, NON_UNIQUE, INDEX_TYPE, cols);
  }
  --end_result();
}
;

yacutia_exec_no_error('drop view db.dba.sql_table_indexes')
;

create procedure view db.dba.sql_table_indexes as
db.dba.sql_table_indexes (tablename) (TABLE_NAME varchar, INDEX_NAME varchar, NON_UNIQUE integer, INDEX_TYPE integer, COLUMNS varchar)
;

create procedure db.dba.vad_packages_meta() returns any
{
  declare retval any;
  retval := vector('id','item_name','Version', 'Release Date', 'Install Date');
  return retval;
}
;



-- Sample content providing procedures for vdir browser.
-- 2 procedures should be supplied - for meta-information and for content.
-- Meta procedure: doesn't have parameters and returns a vector of string names of content columns.
-- Content-providing procedure:
-- Parameters:
-- path - path to get content for
-- filter - filter mask for content
-- Return value:
-- Vector of vectors each describes one content item.
-- Format of item vector:
-- [0] - integer = 1 if item is a container (node), 0 if item is a leaf;
-- [1] - varchar item name;
-- [2] - varchar item icon name (e.g. 'images/txtfile.gif' etc.),
--       if NULL, predefined icons for folder and document will be used according to [0] element
-- [3], [4] .... - optional !varchar! fields to show as item describing info,
--       each element will be placed in its own column in details view.
-- 3rd procedure is optional - it is used for folder creation
-- Parameters:
-- path - path to get content for
-- newfolder - name of the folder to create
-- Return value:
-- integer 1 on success, 0 on error.

create procedure db.dba.vdir_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description');
  return retval;
}
;

create procedure
db.dba.vdir_browse_proc( in path varchar, in filter varchar := '' ) returns any
{
  declare level, is_node integer;
  declare cat, sch, tbl, descr varchar;
  declare retval any;

  retval := vector();
  --  retval := vector_concat(retval,
  --                          vector(vector('ITEM_IS_CONTAINER',
  --                                        'ITEM_NAME',
  --                                        'ICON_NAME',
  --                                        'Description')));

  path := trim(path,'.');

  if (isnull(filter) or filter = '' )
    filter := '%.%.%';
  replace(filter, '*', '%');
  cat := left( path, coalesce(strchr(path,'.'),length(path)));
  path := ltrim(subseq( path, length(cat)), '.');
  cat := trim(cat,'"');
  sch := left( path, coalesce(strchr(path,'.'), length(path)));
  path := ltrim(subseq( path, length(sch)), '.');
  sch := trim(sch,'"');
  tbl := trim(left( path, coalesce(strchr(path,'.'), length(path))),'"');
  --if(tbl<>'') level := 3;
  if(sch<>'') level := 2;
  else if(cat<>'') level := 1;
  else level := 0;
  cat := case when cat <> '' then cat else '%' end;
  sch := case when sch <> '' then sch else '%' end;
  is_node := case when level < 2 then 1 else 0 end;
  descr := case level when 0 then 'Catalog' when 1 then 'Schema' else 'Table' end;

  for( select distinct name_part (KEY_TABLE, level) as ITEM from DB.DBA.SYS_KEYS
       where name_part (KEY_TABLE, 0) like cat and
             name_part (KEY_TABLE, 1) like sch and
             KEY_TABLE LIKE filter
     ) do {
     retval := vector_concat(retval, vector(vector(is_node, ITEM, NULL,descr)));
  }
  return retval;
}
;

create procedure
db.dba.dav_br_map_icon (in type varchar)
{
  if ('folder' = type)
    return ('folder_16.png');
  if ('application/pdf' = type)
    return ('pdf_16.png');
  if ('application/ms-word' = type or 'application/msword' = type)
    return ('docs_16.png');
  if ('application/zip' = type)
    return ('zip_16.png');
  if ('text/html' = type)
    return ('html_16.png');
  if ('text' = "LEFT" (type, 4))
    return ('docs_16.gif');
  if ('image' = "LEFT" (type, 5))
    return ('image_16.png');
  if ('audio' = "LEFT" (type, 5))
    return ('music_16.png');
  if ('video' = "LEFT" (type, 5))
    return ('video_16.png');
  return ('mime_16.png');
}
;

--
-- XXX add weeks, months, years.
--

create procedure
db.dba.yac_hum_min_to_dur (in mins integer)
{
  if (mins < 60) return sprintf ('%d minutes', mins);

  if (mins < 1440)
    return sprintf ('%dhrs,%dmin', mins/60, mod (mins, 60));

  return (sprintf ('%dd,%dhrs,%dmin',
                   mins/1440,
                   mod (mins, 1440)/60,
                   mod (mod (mins, 1440), 60)));
}
;

create procedure
db.dba.yac_hum_datefmt (in d datetime)
{

  declare date_part varchar;
  declare time_part varchar;
  declare min_diff integer;
  declare day_diff integer;

  if (isnull (d))
    {
      return ('Never');
    }

  day_diff := datediff ('day', d, now ());
  if (day_diff < 1)
    {
      min_diff := datediff ('minute', d, now ());
      if (min_diff = 1)
        {
          return ('A minute ago');
        }
      else if (min_diff < 1)
        {
          return ('Less than a minute ago');
        }
      else if (min_diff < 60)
        {
          return (sprintf ('%d minutes ago', min_diff));
        }
      else return (sprintf ('Today at %02d:%02d', hour (d), minute (d)));
    }
  if (day_diff < 2)
    {
      return (sprintf ('Yesterday at %02d:%02d', hour (d), minute (d)));
    }
  return (sprintf ('%02d/%02d/%02d %02d:%02d',
                   year (d),
                   month (d),
                   dayofmonth (d),
                   hour (d),
                   minute (d)));
}
;

--
-- Return byte counts in human-friendly format
--
-- XXX: not localized
--

create procedure
db.dba.yac_hum_fsize (in sz integer) returns varchar
{
  if (sz = 0)
    return ('Zero');
  if (sz < 1024)
    return (sprintf ('%dB', cast (sz as integer)));
  if (sz < 102400)
    return (sprintf ('%.1fkB', sz/1024));
  if (sz < 1048576)
    return (sprintf ('%dkB', cast (sz/1024 as integer)));
  if (sz < 104857600)
    return (sprintf ('%.1fMB', sz/1048576));
  if (sz < 1073741824)
    return (sprintf ('%dMB', cast (sz/1048576 as integer)));
  return (sprintf ('%.1fGB', sz/1073741824));
}
;

create procedure
db.dba.dav_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector('ITEM_IS_CONTAINER',
                   'ITEM_NAME',
                   'ICON_NAME',
                   'Size',
                   'Created',
                   'Description');
  return retval;
}
;

create procedure
db.dba.dav_browse_proc_meta1(in show_details integer := 0) returns any
{
  declare retval any;
  if (show_details = 0)
    retval := vector('ITEM_IS_CONTAINER',
                     'ITEM_NAME',
                     'ICON_NAME',
                     'Size',
                     'Modified',
                     'Type',
                     'Owner',
                     'Group',
                     'Permissions');
  else
    retval := vector('ITEM_IS_CONTAINER', 'ITEM_NAME');
  return retval;
}
;

create procedure
db.dba.dav_browse_proc1 (in path varchar,
                         in show_details integer := 0,
                         in dir_select integer := 0,
                         in filter varchar := '',
                         in search_type integer := -1,
                         in search_word varchar := '',
			 in ord varchar := '',
			 in ordseq varchar := 'asc'
			 ) returns any
{
  declare i, j, len, len1 integer;
  declare dirlist, retval any;
  declare cur_user, cur_group, user_name, group_name, perms, perms_tmp, cur_file varchar;
  declare stat, msg, mdt, dta any;

  cur_user := connection_get ('vspx_user');
  path := replace (path, '"', '');

  if (length (path) = 0 and search_type = -1)
    {
      if (show_details = 0)
        retval := vector (vector (1, 'DAV', NULL, '0', '', 'Root', '', '', ''));
      else
        retval := vector (vector (1, 'DAV'));
      return retval;
    }
  else
    if (length(path) = 0 and search_type <> -1)
      path := 'DAV';

  if (path[length (path) - 1] <> ascii ('/'))
    path := concat (path, '/');

  if (path[0] <> ascii ('/'))
    path := concat ('/', path);

  if (isnull (filter) or filter = '')
    filter := '%';

  replace (filter, '*', '%');
  retval := vector ();
  if (search_type = 0 or search_type = -1)
    {
      if (ord = 'name')
	ord := 11;
      else if (ord = 'size')
	ord := 3;
      else if (ord = 'type')
	ord := 10;
      else if (ord = 'modified')
	ord := 4;
      else if (ord = 'owner')
	ord := 8;
      else if (ord = 'group')
	ord := 7;

      if (isinteger (ord))
	ord := sprintf (' order by %d %s', ord, ordseq);

      if (search_type = 0)
	{
	  --dbg_obj_print ('case 1');
	  exec (concat ('select * from Y_DAV_DIR where path = ? and recursive = ? and auth_uid = ? ', ord),
	     stat, msg, vector (path, 1, cur_user), 0, mdt, dirlist);
	  -- old behaviour
          --dirlist := YACUTIA_DAV_DIR_LIST (path, 1, cur_user);
	}
      else
	{
	  --dbg_obj_print ('case 2');
	  exec (concat ('select * from Y_DAV_DIR where path = ? and recursive = ? and auth_uid = ? ', ord),
	     stat, msg, vector (path, 0, cur_user), 0, mdt, dirlist);
	  --dbg_obj_print (dirlist);
	  -- old behaviour
          -- dirlist := YACUTIA_DAV_DIR_LIST (path, 0, cur_user);
	}

      if (not isarray (dirlist))
        return retval;

      len := length (dirlist);
      i := 0;

      while (i < len)
        {
          if (lower (dirlist[i][1]) = 'c') --  and dirlist[i][10] like filter) -- lets not filter out collections!
            {
              cur_file := trim (dirlist[i][0], '/');
              cur_file := subseq (cur_file, strrchr (cur_file, '/') + 1);

              if (search_type = -1 or
                  (search_type = 0 and cur_file like search_word))
                {
                  if (show_details = 0)
                    {
                      if (dirlist[i][7] is not null)
                        user_name := dirlist[i][7];
                      else
                        user_name := 'none';

                      if (dirlist[i][6] is not null)
                        group_name := dirlist[i][6];
                      else
                        group_name := 'none';

	              perms_tmp := dirlist[i][5];
                      if (length (perms_tmp) = 9)
                        perms_tmp := perms_tmp || 'N';
                      perms := DAV_PERM_D2U (perms_tmp);

                      if (search_type = 0)
                        retval :=
                          vector_concat(retval,
                                        vector (vector (1,
                                                        dirlist[i][0],
                                                        NULL,
                                                        'N/A',
                                                        yac_hum_datefmt (dirlist[i][3]),
                                                        'folder',
                                                        user_name,
                                                        group_name,
                                                        perms)));
                      else
                        retval :=
                          vector_concat(retval,
                                        vector (vector (1,
                                                        dirlist[i][10],
                                                        NULL,
                                                        'N/A',
                                                        yac_hum_datefmt (dirlist[i][3]),
                                                        'folder',
                                                        user_name,
                                                        group_name,
                                                        perms)));
                    }
                  else
                    {
                      if (search_type = 0)
                        retval := vector_concat(retval,
                                                vector (vector (1, dirlist[i][0])));
                      else
                        retval := vector_concat(retval,
                                                vector (vector (1, dirlist[i][10])));
                    }
                  }
                }
              i := i + 1;
            }
          if (dir_select = 0 or dir_select = 2)
            {
              i := 0;
              while (i < len)
                {
                  if (lower (dirlist[i][1]) <> 'c' and dirlist[i][10] like filter)
                    {
                      cur_file := trim (aref (aref (dirlist, i), 0), '/');
                      cur_file := subseq (cur_file, strrchr (cur_file, '/') + 1);

                      if (search_type = -1 or
                          (search_type = 0 and cur_file like search_word))
                        {
                          if (show_details = 0)
                            {
                              if (dirlist[i][7] is not null)
				user_name := dirlist[i][7];
                              else
                                user_name := 'none';

                              if (dirlist[i][6] is not null)
				group_name := dirlist[i][6];
                              else
                                group_name := 'none';

	              	      perms_tmp := dirlist[i][5];
                      	      if (length (perms_tmp) = 9)
                        	perms_tmp := perms_tmp || 'N';
			      perms := DAV_PERM_D2U (perms_tmp);

                              if (search_type = 0)
                                retval :=
                                  vector_concat(retval,
                                                vector (vector (0,
                                                                dirlist[i][0],
                                                                NULL,
                                                                yac_hum_fsize (dirlist[i][2]),
                                                                yac_hum_datefmt (dirlist[i][3]),
                                                                dirlist[i][9],
                                                                user_name,
                                                                group_name,
                                                                perms )));
                              else
                                retval :=
                                  vector_concat(retval,
                                                vector( vector (0,
                                                                dirlist[i][10],
                                                                NULL,
                                                                yac_hum_fsize (dirlist[i][2]),
                                                                yac_hum_datefmt (dirlist[i][3]),
                                                                dirlist[i][9],
                                                                user_name,
                                                                group_name,
                                                                perms )));
                            }
                          else
                            {
                              if (search_type = 0)
                                retval := vector_concat (retval,
                                                         vector(vector(0, dirlist[i][0])));
                              else
                                retval := vector_concat (retval,
                                                         vector(vector(0, dirlist[i][10])));
                            }
                        }
                    }
                    i := i + 1;
                  }
         }
            }
          else
            if (search_type = 1)
              {
                retval := vector();
                declare _u_name, _g_name varchar;
                declare _maxres integer;
                declare _qtype varchar;
                declare _out varchar;
                declare _style_sheet varchar;
                declare inx integer;
                declare _qfrom varchar;
                declare _root_elem varchar;
                declare _u_id, _cutat integer;
                declare _entity any;
                declare _res_name_sav varchar;
                declare _out_style_sheet, _no_matches, _trf, _disp_result varchar;
                declare _save_as, _own varchar;

    -- These parameters are needed for WebDAV browser

                declare _current_uri, _trf_doc, _q_scope, _sty_to_ent,
                _sid_id, _sys, _mod varchar;
                declare _dav_result any;
                declare _e_content any;
                declare stat, err varchar;
                declare _no_match, _last_match, _prev_match, _cntr integer;

                err := ''; stat := '00000';
                _dav_result := null;

                declare exit handler for sqlstate '*'
                  {
                    stat := __SQL_STATE; err := __SQL_MESSAGE;
                  };

	      if (ord = 'name')
		ord := 2;
	      else if (ord = 'size')
		ord := 10;
	      else if (ord = 'type')
		ord := 6;
	      else if (ord = 'modified')
		ord := 7;
	      else if (ord = 'owner')
		ord := 4;
	      else if (ord = 'group')
		ord := 5;

	      if (isinteger (ord))
		ord := sprintf (' order by %d %s', ord, ordseq);

                if (not is_empty_or_null (search_word))
                  {
		    stat := '00000';
                    exec (concat ('select RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP, RES_TYPE, RES_MOD_TIME, RES_PERMS,
                                RES_FULL_PATH, length (RES_CONTENT)
                           from WS.WS.SYS_DAV_RES
                           where contains (RES_CONTENT, ?)', ord), stat, msg, vector (search_word), 0, mdt, dta);


		    if (stat = '00000')
		      {
			declare RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP, RES_TYPE,
				RES_MOD_TIME, RES_PERMS, RES_FULL_PATH any;

			foreach (any elm in dta) do
			  {
			    RES_ID := elm[0];
			    RES_NAME := elm[1];
		            RES_CONTENT := elm[2];
	    		    RES_OWNER := elm[3];
	                    RES_GROUP  := elm[4];
	                    RES_TYPE  := elm[5];
	                    RES_MOD_TIME  := elm[6];
	                    RES_PERMS  := elm[7];
	                    RES_FULL_PATH := elm[8];

			    if (exists (select 1 from WS.WS.SYS_DAV_PROP
					  where PROP_NAME = 'xper' and
						PROP_TYPE = 'R' and
						PROP_PARENT_ID = RES_ID))
			      {
				_e_content := string_output ();
				http_value (xml_persistent (RES_CONTENT), null, _e_content);
				_e_content := string_output_string (_e_content);
			      }
			    else
			      _e_content := RES_CONTENT;

			    if (RES_GROUP is not null and RES_GROUP > 0)
			      {
				_g_name := (select G_NAME from WS.WS.SYS_DAV_GROUP where G_ID = RES_GROUP);
			      }
			    else
			      {
				_g_name := 'no group';
			      }

			    if (RES_OWNER is not null and RES_OWNER > 0)
			      {
				_u_name := (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = RES_OWNER);
			      }
			    else
			      {
				_u_name := 'Public';
			      }

			    if (show_details = 0)
			      {
				retval :=
				  vector_concat (retval,
						 vector (vector (0,
								 RES_FULL_PATH,
								 NULL,
								 yac_hum_fsize (length (RES_CONTENT)),
								 yac_hum_datefmt (RES_MOD_TIME),
								 RES_TYPE,
								 _u_name,
								 _g_name,
								 adm_dav_format_perms (RES_PERMS))));
			      }
			    else
			      {
				retval := vector_concat(retval,
							vector (vector (0,
									RES_FULL_PATH)));
			      }
		            inx := inx + 1;
	                 }
		      }
       }
    }
  return retval;
}
;

create procedure
db.dba.dav_browse_proc (in path varchar,
                        in filter varchar := '' ) returns any
{
  declare i, len integer;
  declare dirlist, retval any;

  path := replace (path, '"', '');
  if (length (path) = 0) {
    retval := vector( vector( 1, 'DAV', NULL, '0', '', 'Root' ));
    return retval;
  }
  if (path[length(path)-1] <> ascii('/'))
    path := concat (path, '/');
  if (path[0] <> ascii('/'))
    path := concat ('/', path);

  if (isnull(filter) or filter = '' )
    filter := '%';
  replace(filter, '*', '%');
  retval := vector();
  dirlist := DAV_DIR_LIST( path, 0, 'dav', 'dav');
  if(not isarray(dirlist))
    return retval;
  len:=length(dirlist);
  i:=0;
  while( i < len ) {
    if (dirlist[i][1] = 'c' /* and dirlist[i][10] like filter */ ) -- let's don't filter out catalogs!
      retval := vector_concat (retval,
                               vector (vector (1,
                                               dirlist[i][10],
                                               NULL,
                                               sprintf('%d', dirlist[i][2]),
                                               left(cast(dirlist[i][3] as varchar), 19),
                                               'Collection' )));
    i := i+1;
  }
  i:=0;
  while( i < len ) {
    if (dirlist[i][1] <> 'c' and dirlist[i][10] like filter )
    retval := vector_concat(retval, vector(vector( 0, dirlist[i][10], NULL, sprintf('%d', dirlist[i][2]), left(cast(dirlist[i][3] as varchar), 19), 'Document' )));
    i := i+1;
  }
  return retval;
}
;

create procedure
db.dba.dav_crfolder_proc (in path varchar,
                          in folder varchar ) returns integer
{
  declare ret integer;

  path := replace (path, '"', '');

  if (length (path) = 0)
    path := '.';

  if (path[length (path)-1] <> ascii ('/'))
    path := concat (path, '/');

  if (folder[length (folder) - 1] <> ascii ('/'))
    folder := concat (folder, '/');

  ret := DB.DBA.DAV_COL_CREATE (path || folder, '110100000R', 'dav', 'dav', 'dav', 'dav');
  return case when ret <> 0 then 0 else 1 end;
}
;


create procedure db.dba.fs_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector ('ITEM_IS_CONTAINER',
                    'ITEM_NAME',
                    'ICON_NAME',
                    'Size',
                    'Created',
                    'Description');
  return retval;
}
;


create procedure fs_chek_filter (in dirlist any, in filters any)
{
   declare idx, len, ret integer;

   len := length (filters);
   ret := 0;
   idx := 0;

   while (idx < len)
     {
  if (dirlist like filters[idx])
    return 1;
  idx := idx + 1;
     }

   return ret;
}
;


create procedure
hm_filter_list ()
{
   if (adm_is_hosted () = 1)
     return '*.dll; *.exe';
   if (adm_is_hosted () = 2)
     return '*.class; *.zip';
   if (adm_is_hosted () = 3)
     return '*.dll; *.exe; *.class; *.zip';

   return '';
}
;

create procedure
db.dba.fs_browse_proc_empty (in path varchar, in show_details integer := 0, in filter varchar := '', in ord any := '', in ordseq any := 'asc')
{
  return vector();
};

create procedure fs_browse_proc (in path varchar, in show_details integer := 0, in filter varchar := '', in ord any := '', in ordseq any := 'asc')
{
  declare stat, msg, mdt, dta any;

      if (ord = 'name')
	ord := 2;
      else if (ord = 'size')
	ord := 4;
      else if (ord = 'modified')
	ord := 5;
      else if (ord = 'description')
	ord := 6;

      if (isinteger (ord))
	ord := sprintf (' order by %d %s', ord, ordseq);
      else
        ord := '';

  exec ('select * from Y_FS_DIR where path = ? and show_details = ? and filter = ? ' || ord
      , stat, msg, vector (path,show_details,filter), 0, mdt, dta);

  return dta;
}
;

yacutia_exec_no_error('create procedure view Y_FS_DIR as db.dba.fs_browse_proc_p (path,show_details,filter) (TYPE int, NAME varchar, MIME varchar, SIZE int, MODF datetime, FTYPE varchar)');

create procedure
db.dba.fs_browse_proc_p (in path varchar,
                       in show_details integer := 0,
                       in filter varchar := '' ) returns any
{
  declare i, len integer;
  declare dirlist, retval, filters any;
  declare f_type, f_name, f_mime, f_size, f_date, f_ftype any;

  result_names (f_type, f_name, f_mime, f_size, f_date, f_ftype);

  path := replace (path, '"', '');

  if (length (path) = 0)
    path := '.';

  if (path [length (path) - 1] <> ascii ('/'))
    path := concat (path, '/');

  if (filter = '__hosted_modules_list')
    filter := hm_filter_list ();

  if (isnull (filter) or filter = '' )
    filter := '%';

  filter := replace (filter, '*', '%');
  filter := replace (filter, ' ', '');

  if (strstr (filter, ';') is NULL)
   filters := vector (filter);
  else
   filters := split_and_decode (filter, 0, '\0\0;');

  retval := vector ();

  dirlist := sys_dirlist (path, 0);

  if (not isarray (dirlist))
    return;

  len := length (dirlist);

  i := 0;

  while (i < len)
    {
      if (dirlist[i] <> '.' and dirlist[i] <> '..')
        {
	  declare mod any;
	  f_type := 1;
	  f_name := dirlist[i];
	  f_mime := null;
	  f_size := -1;
	  mod := file_stat (path||dirlist[i], 0);
	  if (isstring(mod))
	    {
	      f_date := stringdate(mod);
	      f_ftype := 'Folder';
	      result (f_type, f_name, f_mime, f_size, f_date, f_ftype);
	    }
        }
      i := i + 1;
    }

  dirlist := sys_dirlist (path, 1);

  if (not isarray (dirlist))
    return;

 len := length (dirlist);

  i := 0;

  while (i < len)
    {
      if (fs_chek_filter (dirlist [i], filters))  -- we filter out files only
        {
	  declare ssize any;
	  f_type := 0;
	  f_name := dirlist[i];
	  f_mime := null;
	  ssize := file_stat (path || dirlist[i], 1);
	  if (isstring (ssize))
	    {
	      f_size := atoi(ssize);
	      f_date := stringdate (file_stat (path||dirlist[i], 0));
	      f_ftype := 'File';
	      result (f_type, f_name, f_mime, f_size, f_date, f_ftype);
	    }
        }
      i :=  i + 1;
    }
  return;
}
;

create procedure
db.dba.fs_crfolder_proc (in path varchar,
                         in folder varchar ) returns integer
{
  declare mk_dir_id integer;

  path := replace (path, '"', '');

  if (length (path) = 0)
    path := '.';

  if (path [length (path) - 1] <> ascii ('/'))
    path := concat (path, '/');

  return sys_mkdir (path || folder);
}
;

create procedure
db.dba.vproc_browse_proc_meta () returns any
{
  declare retval any;
  retval := vector ('ITEM_IS_CONTAINER', 'ITEM_NAME', 'ICON_NAME', 'Description');
  return retval;
}
;

create procedure
db.dba.vproc_browse_proc (in path varchar,
                          in filter varchar := '' ) returns any
{
  declare level, is_node integer;
  declare cat, sch, tbl, descr varchar;
  declare retval any;

  retval := vector();

  --retval := vector_concat(retval, vector(vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description')));

  if (isnull (filter) or filter = '')
    filter := '%.%.%';

  replace (filter, '*', '%');

  path := trim (path,'.');
  cat := left (path, coalesce (strchr (path,'.'), length (path)));
  path := ltrim (subseq (path, length (cat)), '.');
  cat := trim (cat,'"');

  sch := left (path, coalesce (strchr (path,'.'), length (path)));
  path := ltrim (subseq (path, length(sch)), '.');
  sch := trim (sch,'"');
  tbl := trim (left (path, coalesce (strchr (path,'.'), length (path))),'"');

  if (sch <> '')
    level := 2;
  else if (cat <> '')
    level := 1;
  else
    level := 0;

  cat := case when cat <> '' then cat else '%' end;
  sch := case when sch <> '' then sch else '%' end;

  is_node := case when level < 2 then 1 else 0 end;
  descr := case level when 0 then 'Catalog' when 1 then 'Schema' else 'Procedure' end;

  if (cat = 'DB' AND sch = 'DBA')
    {
      retval := vector_concat (retval,
                               vector (vector (is_node,
                                               'HP_AUTH_SQL_USER',
                                               NULL,
                                               'Built-in')));
      retval := vector_concat (retval,
                               vector (vector (is_node,
                                               'HP_AUTH_DAV_ADMIN',
                                               NULL,
                                               'Built-in')));
      retval := vector_concat (retval,
                               vector (vector (is_node,
                                               'HP_AUTH_DAV_PROTOCOL',
                                               NULL,
                                               'Built-in')));
    }
  if (cat = 'WS' AND sch = 'WS')
    {
      retval := vector_concat(retval,
                              vector (vector (is_node,
                                              'DIGEST_AUTH',
                                              NULL,
                                              'Built-in')));
    }

  for (select DISTINCT name_part (P_NAME, level) AS ITEM
         from SYS_PROCEDURES
         where name_part(P_NAME, 0) LIKE cat and
               name_part (P_NAME, 1) like sch and
               P_NAME not like '%.%./%' and
               P_NAME like filter
         order by P_NAME) do
    {
      retval := vector_concat(retval,
                              vector(vector(is_node, ITEM, NULL, descr)));
    }
  return retval;
}
;

create procedure
db.dba.vview_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector ('ITEM_IS_CONTAINER', 'ITEM_NAME', 'ICON_NAME', 'Description');
  return retval;
}
;

create procedure
db.dba.vview_browse_proc (in path varchar,
                          in filter varchar := '') returns any
{
  declare level, is_node integer;
  declare cat, sch, tbl, descr varchar;
  declare retval any;

  retval := vector ();
  --retval := vector_concat(retval, vector(vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description')));

  if (isnull (filter) or filter = '' )
    filter := '%.%.%';
  replace(filter, '*', '%');

  path := trim (path,'.');
  cat := left (path, coalesce (strchr (path,'.'), length(path)));
  path := ltrim (subseq (path, length (cat)), '.');
  cat := trim (cat,'"');

  sch := left (path, coalesce (strchr (path,'.'), length (path)));
  path := ltrim (subseq (path, length (sch)), '.');
  sch := trim (sch,'"');
  tbl := trim (left (path, coalesce (strchr (path,'.'), length (path))),'"');

  --if(tbl<>'') level := 3;

  if (sch <> '')
    level := 2;
  else if (cat <> '')
    level := 1;
  else
    level := 0;

  cat := case when cat <> '' then cat else '%' end;
  sch := case when sch <> '' then sch else '%' end;

  is_node := case when level < 2 then 1 else 0 end;
  descr := case level when 0 then 'Catalog' when 1 then 'Schema' else 'View' end;

  for(select distinct name_part (KEY_TABLE, level) as ITEM
        from DB.DBA.SYS_KEYS
        where name_part (KEY_TABLE, 0) like cat and
              name_part (KEY_TABLE, 1) like sch and
              table_type (KEY_TABLE) = 'VIEW' and
              KEY_IS_MAIN = 1 and
              KEY_MIGRATE_TO is NULL and
              KEY_TABLE like filter) do
    {
      retval := vector_concat (retval,
                               vector (vector (is_node, ITEM, NULL, descr)));
    }
  return retval;
}
;

create procedure DB.DBA.MSG_NEWS_DOWNLOAD_MESSAGES(in _ns_id integer, in _ng_id integer, in _mode varchar)
{
  if (isstring (_ng_id))
      new_news (atoi (_ng_id));
  return '';
}
;

create procedure
DB.DBA.MSG_NEWS_CLEAR_MESSAGES (in _ns_id integer,
                                in _ng_id integer,
                                in _mode varchar default '')
{
  declare _group_status, _group_pass, _group_first, _group_last, _group_last_out any;
  declare _server, _user, _password, _group_name, _max_body_id any;

  -- get news group parameters
  select NG_NAME,
         NG_PASS,
         NG_FIRST,
         NG_LAST,
         NG_LAST_OUT,
         NG_STAT
    into _group_name,
         _group_pass,
         _group_first,
         _group_last,
         _group_last_out,
         _group_status
    from DB.DBA.NEWS_GROUPS
    where NG_GROUP = _ng_id and
          NG_SERVER = _ns_id;

  -- check if retrieving already started by another process

  if (_group_status = 9)
    return 'Group already updating...';

  -- mark group as updating
  update DB.DBA.NEWS_GROUPS
  set NG_STAT = 9
  where NG_GROUP = _ng_id and
        NG_SERVER = _ns_id;

  commit work;

  {
    declare _nm_num_group, _nm_key_id any;
    declare cr cursor for
      select NM_NUM_GROUP, NM_KEY_ID
      from DB.DBA.NEWS_MULTI_MSG
      where NM_GROUP = _ng_id
      order by 1;

    whenever not found goto _end_cycle;

    open cr (exclusive, prefetch 1);

    while (1)
      {
        fetch cr into _nm_num_group, _nm_key_id;

        if (_nm_num_group >= _group_last_out and _mode <> 'clear all')
          goto _end_cycle;

        delete from DB.DBA.NEWS_MULTI_MSG
          where NM_KEY_ID = _nm_key_id;

        delete from DB.DBA.NEWS_MSG
          where NM_ID = _nm_key_id;
    }
_end_cycle:
      commit work;
  }

  update DB.DBA.NEWS_GROUPS
    set NG_STAT = 1
    where NG_GROUP = _ng_id and
          NG_SERVER = _ns_id;

  commit work;

  return '';
}
;

create procedure db.dba.yac_user_caps_meta() returns any
{
  declare retval any;
  retval := vector ('Type','Name','Permissions', 'Inherited Permissions');
  return retval;
}
;

create procedure
db.dba.yac_user_caps (in username varchar,
                      in filter varchar,
                      in show_all integer,
                      in tabls integer := 1,
                      in views integer := 1,
                      in procs integer := 1,
		      in ord any := null,
		      in ordseq any := 'asc')
{
  declare mtd, dta any;
  declare inh any;
  declare sql varchar;
  DECLARE user_ident, pars VARCHAR;



  select U_ID into user_ident from SYS_USERS where U_NAME = username;

  inh := vector ();
  GET_INHERITED_GRANTS (user_ident, user_ident, inh);

  inh := vector_concat (vector (user_ident), inh);


  if (isnull (filter) or filter = '' )
    filter := '%.%.%';

 if (length (ord))
   {
     if (ord = 'name')
       ord := ' order by 2 ' || ordseq;
     else if (ord = 'type')
       ord := ' order by 5 ' || ordseq;
     else if (ord = 'owner')
       ord := ' order by 6 ' || ordseq;
     else
       ord := '';
   }
 else
   ord := '';


  sql := '';

  pars := vector ();

  if (tabls <> 0)
    {
      sql := sql ||
       'select distinct 1, KEY_TABLE, cast (direct_grants(KEY_TABLE, ? ) as int) as dg, indirect_grants(KEY_TABLE, ?) as ig
       , ''Table'' as rt, name_part (KEY_TABLE, 1) as own
       from DB.DBA.SYS_KEYS
       where KEY_TABLE like ?
         and table_type (KEY_TABLE) = ''TABLE''
         and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is NULL ' ||
       case when show_all = 0 then 'AND __any_grants_to_user(KEY_TABLE, ?) ' else '' end ;
       --	   || 'order by KEY_TABLE';
       pars := vector (user_ident, inh, filter);
       if (show_all = 0)
	 pars := vector_concat (pars, vector (username));
      --exec (sql, null, null, vector (1, user_ident, inh, filter, 'TABLE', username), 0, mtd, dta);
      --retval := vector_concat (retval, dta);
    }

  if ( views <> 0)
    {
      sql := sql || case when length (sql) then ' union all ' else '' end ||
       'select distinct 2, KEY_TABLE, cast (direct_grants(KEY_TABLE, ? ) as int) as dg, indirect_grants(KEY_TABLE, ?) as ig
       , ''View'' as rt, name_part (KEY_TABLE, 1) as own
       from DB.DBA.SYS_KEYS
       where KEY_TABLE like ?
         and table_type (KEY_TABLE) = ''VIEW''
         and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is NULL ' ||
       case when show_all = 0 then 'AND __any_grants_to_user(KEY_TABLE, ?) ' else '' end ;
      pars := vector_concat (pars, vector (user_ident, inh, filter));
      if (show_all = 0)
	pars := vector_concat (pars, vector (username));
      --exec (sql, null, null, vector (2, user_ident, inh, filter, 'VIEW', username), 0, mtd, dta);
      --retval := vector_concat (retval, dta);
    }

  if (procs <> 0)
    {
      sql := sql || case when length (sql) then ' union all ' else '' end ||
      'select 3, P_NAME, cast (direct_grants(P_NAME, ? ) as int) as dg, indirect_grants(P_NAME, ?) as ig
       , ''Procedure'' as rt, name_part (P_NAME, 1) as own
       from DB.DBA.SYS_PROCEDURES
       where P_NAME like ? ' || case when show_all=0 then 'AND __any_grants_to_user(P_NAME, ?) ' else '' end;
       --|| 'order by P_NAME';

      pars := vector_concat (pars, vector (user_ident, inh, filter));
      if (show_all = 0)
	pars := vector_concat (pars, vector (username));
      --exec (sql, null, null, vector (user_ident, inh, filter, username), 0, mtd, dta);
      --retval := vector_concat(retval, dta);
  }

 if (sql = '')
   return vector ();

 sql := sql || ord;

 exec (sql, null, null, pars, 0, mtd, dta);
 done:
  return dta;
}
;

create procedure
direct_grants( in object_name varchar, in user_id integer, in colname varchar := '_all' ) returns integer
{
  declare dg int;
  dg := 0;

  for( select G_OP from SYS_GRANTS where G_USER = user_id and G_OBJECT = object_name and G_COL in ('_all', colname)) do {
    dg := bit_or( dg, G_OP );
  }
  return dg;
}
;

create procedure
indirect_grants (in object_name varchar,
                 in user_ids any,
                 in colname varchar := '_all') returns varchar
{
  declare dg int;
  declare grants varchar;
  grants := '------';
  declare i, u int;

  i := 0;

  while (i < length(user_ids))
    {
      if (user_ids[i] = 0 or user_ids[i] = 3) -- DBA user or group
        return 'AAAAAA';
      i := i + 1;
    }

  -- public object
    for (select G_OP
           from SYS_GRANTS
           where G_USER = 1 and
                 G_OBJECT = object_name and
                 G_COL in ('_all', colname)) do
      {
        i := 0;

        while(i < 6)
          {
            if (bit_and (bit_shift (1, i), G_OP))
              grants[i] := ascii ('P');
            i := i + 1;
          }
      }

    u := 0;

    while (u < length (user_ids))
      {
    -- object is granted to user

        for (select G_OP
               from SYS_GRANTS
               where G_USER = user_ids[u] and
                     G_OBJECT = object_name and
                     G_COL in ('_all', colname)) do
          {
            i := 0;
            while (i < 6)
              {
                if (bit_and (bit_shift (1, i), G_OP))
                  grants[i] := ascii('+');
                i := i + 1;
              }
          }
        u := u + 1;
      }
  return grants;
}
;

create procedure adm_get_users (in mask any := '%', in ord any := '', in seq any := 'asc')
{
  declare sql, dta, mdta, rc, h, tmp any;

  declare U_NAME, U_FULL_NAME, U_LOGIN_TIME, U_EDIT_TIME any;
  result_names (U_NAME, U_FULL_NAME, U_LOGIN_TIME, U_EDIT_TIME);
  if (not isstring (mask))
    mask := '%';
  sql := 'select U_NAME, coalesce (U_FULL_NAME, \'\') as U_FULL_NAME, U_LOGIN_TIME, cast (USER_GET_OPTION (U_NAME, \'ConductorEdit\') as datetime)
          from SYS_USERS where  U_IS_ROLE = 0 and (upper (U_NAME) like upper (?)) ';
  if (length (ord))
    {
      tmp := case ord when 'name' then '1' when 'fullname' then '2' when 'login' then '3' when 'edit' then '4' else '' end;
      if (tmp <> '')
	{
	  ord := 'order by ' || tmp || ' ' || seq;
	  sql := sql || ord;
	}
    }
  rc := exec (sql, null, null, vector (mask), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    exec_result (dta);
  exec_close (h);
}
;

create procedure adm_get_all_users (in mask any := '%', in ord any := '', in seq any := 'asc')
{
  declare sql, dta, mdta, rc, h, tmp any;

  declare U_NAME, U_FULL_NAME, U_LOGIN_TIME, U_EDIT_TIME any;
  result_names (U_NAME, U_FULL_NAME, U_LOGIN_TIME, U_EDIT_TIME);
  if (not isstring (mask))
    mask := '%';
  sql := 'select U_NAME, coalesce (U_FULL_NAME, \'\') as U_FULL_NAME, U_IS_ROLE
          from SYS_USERS where (upper (U_NAME) like upper (?)) ';
  if (length (ord))
    {
      tmp := case ord when 'name' then '1' when 'fullname' then '2' when 'type' then '3' else '' end;
      if (tmp <> '')
	{
	  ord := 'order by ' || tmp || ' ' || seq;
	  sql := sql || ord;
	}
    }
  rc := exec (sql, null, null, vector (mask), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    exec_result (dta);
  exec_close (h);
}
;

yacutia_exec_no_error('create procedure view Y_SYS_USERS_USERS as adm_get_users (mask, ord, seq) (U_NAME varchar, U_FULL_NAME varchar, U_LOGIN_TIME datetime, U_EDIT_TIME datetime)');

yacutia_exec_no_error('create procedure view Y_SYS_USERS as adm_get_all_users (mask, ord, seq) (U_NAME varchar, U_FULL_NAME varchar, U_IS_ROLE int)');

create procedure adm_get_scheduled_events (in ord any := '', in seq any := 'asc')
{
  declare SE_NAME, SE_START, SE_LAST_COMPLETED, SE_INTERVAL, SE_LAST_ERROR, SE_NEXT any;
  declare  sql, dta, mdta, rc, h, tmp any;
  result_names (SE_NAME, SE_START, SE_LAST_COMPLETED, SE_INTERVAL, SE_LAST_ERROR, SE_NEXT);
  sql := 'select SE_NAME, SE_START, SE_LAST_COMPLETED, SE_INTERVAL, case when length (SE_LAST_ERROR) then ''error'' else null end,
          case when SE_LAST_COMPLETED is not null then datediff (''minute'', SE_LAST_COMPLETED, now()) else null end
          from DB.DBA.SYS_SCHEDULED_EVENT';
  if (length (ord))
    {
      tmp := case ord when 'name' then '1' when 'start' then '2' when 'last' then '3'
       when 'interval' then '4' when 'error' then '5' when 'next' then '6' else '' end;
      if (tmp <> '')
	{
	  ord := ' order by ' || tmp || ' ' || seq;
	  sql := sql || ord;
	}
    }
  rc := exec (sql, null, null, vector (), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    exec_result (dta);
  exec_close (h);
}
;

yacutia_exec_no_error('create procedure view Y_SYS_SCHEDULED_EVENT as adm_get_scheduled_events (ord, seq) (SE_NAME varchar, SE_START datetime, SE_LAST_COMPLETED datetime, SE_INTERVAL int, SE_LAST_ERROR varchar, SE_NEXT int)');

--select indirect_grants( 'WS.SOAP.countTheEntities', vector(103));
--select G_OP from SYS_GRANTS where G_USER = 103 and G_OBJECT = 'WS.SOAP.countTheEntities' and G_COL in ('_all', '_all');

create procedure
adm_get_init_name ()
{
  declare _all varchar;

  _all := virtuoso_ini_path();

  if (sys_stat ('st_build_opsys_id') = 'Win32')
    {
      while (length (_all) > 0)
        {
          declare pos integer;

          pos := strstr (_all, '\\');

          if (pos is NULL)
            return _all;

          _all := subseq (_all, pos + 1);
        }
    }
  else
    return _all;
}
;


create procedure
YACUTIA_DAV_COPY (in path varchar,
                  in destination varchar,
                  in overwrite integer := 0,
                  in permissions varchar := '110100000R',
                  in uid integer := NULL,
                  in gid integer := NULL)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = cur_user);

  rc := DAV_COPY (path, destination, overwrite, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_MOVE (in path varchar,
                  in destination varchar,
                  in overwrite varchar)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = cur_user);

  rc := DAV_MOVE (path, destination, overwrite, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_STATUS (in status integer) returns varchar
{
  if (status = -1)
    return 'Invalid target path';

  if (status = -2)
    return 'Invalid destination path';

  if (status = -3)
    return 'Destination already exists and overwrite flag not set';

  if (status = -4)
    return 'Invalid target type (resource) in copy/move';

  if (status = -5)
    return 'Invalid permissions';

  if (status = -6)
    return 'Invalid uid';

  if (status = -7)
    return 'Invalid gid';

  if (status = -8)
    return 'Target is locked';

  if (status = -9)
    return 'Destination is locked';

  if (status = -10)
    return 'Property name is reserved (protected or private)';

  if (status = -11)
    return 'Property does not exists';

  if (status = -12)
    return 'Authentication failed';

  if (status = -13)
    return 'Insufficient privileges for operation';

  if (status = -14)
    return 'Invalid target type';

  if (status = -15)
    return 'Invalid umask';

  if (status = -16)
    return 'Property already exists';

  if (status = -17)
    return 'Invalid property value';

  if (status = -18)
    return 'No such user';

  if (status = -19)
    return 'No home directory';

  return sprintf ('Unknown error %d', status);
}
;

create procedure
YACUTIA_DAV_DELETE (in path varchar,
                    in silent integer := 0,
                    in extern integer := 1)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = cur_user);

  rc := DAV_DELETE_INT (path, silent, cur_user, pwd1, extern);
  return rc;
}
;

create procedure
YACUTIA_DAV_RES_UPLOAD (in path varchar,
                        inout content any,
                        in type varchar := '',
                        in permissions varchar := '110100000R',
                        in uid varchar := 'dav',
                        in gid varchar := 'dav',
                        in cr_time datetime := null,
                        in mod_time datetime := null,
                        in _rowguid varchar := null)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = cur_user);

  rc := DAV_RES_UPLOAD_STRSES (path, content, type, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_COL_CREATE (in path varchar,
                        in permissions varchar,
                        in uid varchar,
                        in gid varchar)
{
  declare rc integer;
  declare pwd1, cur_user any;

  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = cur_user);

  rc := DAV_COL_CREATE (path, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_DIR_LIST (in path varchar := '/DAV/',
                      in recursive integer := 0,
                      in auth_uid varchar := 'dav')
{
  declare res, pwd1 any;

  if (auth_uid = 'dba')
    auth_uid := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = auth_uid);
  res := DAV_DIR_LIST (path, recursive, auth_uid, pwd1);
  return res;
}
;

create procedure
YACUTIA_DAV_DIR_LIST_P (in path varchar := '/DAV/', in recursive integer := 0, in auth_uid varchar := 'dav')
{
  declare arr, pwd1 any;
  declare i, l integer;
  declare FULL_PATH, PERMS, MIME_TYPE, NAME varchar;
  declare TYPE char(1);
  declare RLENGTH, ID, GRP, OWNER integer;
  declare MOD_TIME, CR_TIME datetime;
  result_names (FULL_PATH, TYPE, RLENGTH, MOD_TIME, ID, PERMS, GRP, OWNER, CR_TIME, MIME_TYPE, NAME);

  if (auth_uid = 'dba')
    auth_uid := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = auth_uid);
  arr := DAV_DIR_LIST (path, recursive, auth_uid, pwd1);
  i := 0; l := length (arr);
  while (i < l)
    {
      declare own, grp any;
      own := 'none';
      grp := 'none';
      if (arr[i][7] is not null)
        own := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = arr[i][7]), 'none');
      if (arr[i][6] is not null)
        grp := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = arr[i][6]), 'none');
      result (arr[i][0],
	  arr[i][1],
	  arr[i][2],
	  arr[i][3],
	  case when isinteger (arr[i][4]) then arr[i][4] else -1 end,
	  arr[i][5],
	  grp,
	  own,
	  arr[i][8],
	  arr[i][9],
	  arr[i][10]);
      i := i + 1;
    }
}
;

yacutia_exec_no_error('create procedure view Y_DAV_DIR as YACUTIA_DAV_DIR_LIST_P (path,recursive,auth_uid) (FULL_PATH varchar, TYPE varchar, RLENGTH integer, MOD_TIME datetime, ID integer, PERMS varchar, GRP varchar, OWNER varchar, CR_TIME datetime, MIME_TYPE varchar, NAME varchar)')
;

create procedure
dav_path_validate (in path varchar,
                   out folder_owner integer,
                   out folder_group integer,
                   out folder_perms varchar,
                   out message varchar)
{
  declare  sl_pos, cname_size,c_id, flag, c_owner, c_group integer;
  declare path_tree, cname, cperm varchar;

  message := 'Folder not found.';
  whenever not found goto not_found;

  if (substring(path,1,5) <> '/DAV/' )
    {
      message := sprintf('path %s is incorrect. Must start from /DAV/...', path );
      goto not_found;
    }

  sl_pos := coalesce (strrchr (path, '/'), 0);
  path_tree :=  substring(path,1,sl_pos);
  flag := 0;

  while (sl_pos > 0)
    {
      sl_pos := coalesce ( strrchr (path_tree, '/'),0);
      cname_size :=  length(path_tree) - sl_pos;
      cname := substring(path_tree, sl_pos +2, cname_size);
      if (exists (select 1 from WS.WS.SYS_DAV_COL where COL_NAME = cname))
        {
          select COL_ID,
                 COL_OWNER,
                 COL_GROUP,
                 COL_PERMS
            into c_id,
                 c_owner,
                 c_group,
                 cperm
            from WS.WS.SYS_DAV_COL
            where COL_NAME = cname;

          if (flag = 0)
            {
              folder_perms := cperm;
              folder_owner := c_owner;
              folder_group := c_group;
              flag := 1;
            }

        }
      else
        {
          message := sprintf ('Folder %s does not exist.', path_tree );
          goto not_found;
        }
      if (sl_pos > 0)
        path_tree := substring (path_tree,1,sl_pos);
    }
  return 1;
 not_found:
  return 0;
}
;

create procedure
dav_check_permissions (in user_name varchar,
                       in file_perms varchar,
                       in mask varchar,
                       in dav_folder_owner integer,
                       in dav_folder_group integer,
                       out message varchar)
{
  declare a_user_name, user_id, g_id, vmask varchar;
  declare i integer;

  vmask := '000';
  whenever not found goto not_found;

  if (user_name = 'dba')
    return 1;

  if (exists (select 1 from ws.ws.SYS_DAV_USER where U_NAME = user_name))
    {
      select U_ID, U_GROUP into user_id, g_id from ws.ws.SYS_DAV_USER where U_NAME = user_name;

      if (user_id = http_dav_uid () or g_id = http_dav_uid () + 1)
        return 1;

      if (length (file_perms) < 9 or length (mask) < 3)
        goto not_found;

      if (dav_folder_owner = user_id)
        {
       ; -- You are owner of this folder
          --dbg_obj_print('You are owner of this folder');

          i:= 0;

          while (i < 3)
            {
              if (chr (aref (mask,i)) = '1' and chr (aref (file_perms,i)) = '1')
                aset(vmask,i,ascii('1'));
              i := i + 1;
            }

          if (
              ((chr(aref(mask,0)) = '1' and chr(aref(vmask,0)) = '1') or
               (chr(aref(mask,0)) = '0' and chr(aref(vmask,0)) = '0')) and
              ((chr(aref(mask,1)) = '1' and chr(aref(vmask,1)) = '1') or
               (chr(aref(mask,1)) = '0' and chr(aref(vmask,1)) = '0')) and
              ((chr(aref(mask,2)) = '1' and chr(aref(vmask,2)) = '1') or
               (chr(aref(mask,2)) = '0' and chr(aref(vmask,2)) = '0'))
             )
            return 1;
        }

      if (dav_folder_group = g_id)
        {
    ; -- you are member if group, to which this folder belongs.
          --dbg_obj_print('you are member if group, to which this folder belongs.');

          i:= 0;

          while (i < 3)
            {
              if (chr(aref(mask,i)) = '1' and chr(aref(file_perms,i +3)) = '1')
                aset(vmask,i,ascii('1'));

              i := i + 1;
            }

          if (
              ((chr(aref(mask,0)) = '1' and chr(aref(vmask,0)) = '1') or
               (chr(aref(mask,0)) = '0' and chr(aref(vmask,0)) = '0' )) and
              ((chr(aref(mask,1)) = '1' and chr(aref(vmask,1)) = '1') or
               (chr(aref(mask,1)) = '0' and chr(aref(vmask,1)) = '0')) and
              ((chr(aref(mask,2)) = '1' and chr(aref(vmask,2)) = '1') or
               (chr(aref(mask,2)) = '0' and chr(aref(vmask,2)) = '0'))
             )
            return 1;
        }
      if (exists (select 1
                   from SYS_ROLE_GRANTS
                   where GI_SUPER=user_id and GI_SUB = dav_folder_group ))
        {
      ; --  group, to which folder belongs , is granted to you
          --dbg_obj_print('  group, to which folder belongs , is granted to you');

          i:= 0;

          while (i < 3)
            {
              if (chr (aref (mask, i)) = '1' and chr (aref (file_perms, i + 3)) = '1')
                aset(vmask,i,ascii('1'));

              i := i + 1;
            }
          if (
              ((chr (aref (mask, 0)) = '1' and chr (aref (vmask, 0)) = '1') or
               (chr (aref (mask, 0)) = '0' and chr (aref (vmask, 0)) = '0'))
              and
              ((chr (aref (mask, 1)) = '1' and chr (aref (vmask, 1)) = '1') or
               (chr (aref (mask, 1)) = '0' and chr (aref (vmask, 1)) = '0'))
              and
              ((chr (aref (mask, 2)) = '1' and chr (aref (vmask, 2)) = '1') or
               (chr (aref (mask, 2)) = '0' and chr (aref (vmask, 2)) = '0')))
            return 1;
        }
    -- You are among others
      --dbg_obj_print('You are among others');

      i:= 0;

      while (i < 3)
        {
          if (chr (aref (mask,i)) = '1' and chr (aref (file_perms, i + 6)) = '1')
            aset (vmask,i,ascii('1'));
          i := i + 1;
        }

      if (
          ((chr (aref (mask, 0)) = '1' and chr (aref (vmask, 0)) = '1') or
           (chr (aref (mask, 0)) = '0' and chr (aref (vmask, 0)) = '0' ))
          and
          ((chr (aref (mask, 1)) = '1' and chr (aref (vmask, 1)) = '1') or
           (chr (aref (mask, 1)) = '0' and chr (aref (vmask, 1)) = '0'))
          and
          ((chr (aref (mask, 2)) = '1' and chr (aref (vmask, 2)) = '1') or
           (chr (aref (mask, 2)) = '0' and chr (aref (vmask, 2)) = '0' ))
         )
        return 1;

      goto not_found;

    }
  else
    {
      message := sprintf ('Account %s does not have DAV login enabled.', user_name);
      return 0;
    }

 not_found:
  message := 'Access denied.';
  return 0;
}
;

create procedure
check_dav_file_permissions (in path varchar,
                            in user_name varchar,
                            in actions varchar,
                            out message varchar)
{
  declare file_perms varchar;
  declare file_owner, file_group  integer;

  whenever  not found goto not_found;
  if (not exists (select 1 from ws.ws.SYS_DAV_USER where U_NAME = user_name))
    {
      message := sprintf('Access into DAV is denied for user: %s.',user_name);
      return 0;
    }

  if (not exists (select 1 from WS.WS.SYS_DAV_RES  where RES_FULL_PATH = path))
    goto not_found;

  select RES_PERMS,
         RES_OWNER,
         RES_GROUP
    into file_perms,
         file_owner,
         file_group
    from WS.WS.SYS_DAV_RES
    where RES_FULL_PATH = path;

  return dav_check_permissions (user_name,
                                file_perms,
                                actions,
                                file_owner,
                                file_group,
                                message);
 not_found:
  message := sprintf ('File %s does not exist.', path);
  return 0;
}
;

create procedure
get_sql_tables (in dsn varchar,
                in cat varchar,
                in sch varchar,
                in table_mask varchar,
                in obj_type varchar)
{
  declare key_list, cat_list, sch_list, tables_list any;
  declare i, len, j, lz, sz, n, is_found integer;
  declare c_cat, c_sch, m_mask, v varchar;
  cat_list := vector ();
  sch_list := vector ();

  --dbg_printf ('get_sql_tables: \ndsn: %s\ncat: %s\nsch: %s\nmsk: %s\ntpe: %s\n',
  --            dsn, cat, sch, table_mask, obj_type);

  if (cat ='%' or sch = '%')
    {
       key_list := sql_tables (dsn, null, null, null, null);
    }

  if (cat = '%')
    {
      i:= 0; len :=  length (key_list);

      while (i < len)
        {
          v := aref (aref (key_list, i), 0);
	  if (v is null)
	    v := '%';
          if (v is not null and not position (v, cat_list))
            cat_list := vector_concat (cat_list, vector (v));
          i := i + 1;
        }
    }
  else
    cat_list := vector_concat (cat_list, vector(cat));

--  dbg_obj_print (cat_list);

  if (sch = '%')
    {
      i := 0; len :=  length (key_list);
      while (i < len)
        {
          v := aref (aref (key_list, i), 1);
          if (v is not null and not position (v, sch_list))
            sch_list := vector_concat (sch_list, vector (v));

          i := i + 1;
       }
    }
  else
    sch_list := vector_concat (sch_list, vector (sch));

--  dbg_obj_print (sch_list);

   -- now  fetch all records

   if (table_mask is not null)
     m_mask := table_mask;
   else
     m_mask := '%';

   tables_list := vector();
   i := 0; len := length (cat_list);

   while (i < len)
     {
       c_cat := aref (cat_list, i);
       j := 0; lz := length (sch_list);

       while (j < lz)
         {
	   declare tbls any;
           c_sch := aref (sch_list, j);
           --dbg_printf ('extracting from schema: %s', c_sch);
	   if (c_cat = '%')
	     c_cat := null;
	   tbls := sql_tables (dsn, c_cat, c_sch, null, obj_type);
	   if (m_mask = '%')
	     {
	       tables_list := vector_concat (tables_list, tbls);
	     }
	   else
	     {
	       foreach (any tbl in tbls) do
		 {
		   if (length (tbl) > 1 and tbl[2] is not null and tbl[2] like m_mask)
		     {
		       tables_list := vector_concat (tables_list, vector (tbl));
		     }
		 }
	     }
           j := j + 1;
         }
       i:= i + 1;
     }
--   dbg_obj_print (tables_list);
   return tables_list;
}
;


create procedure
get_sql_procedures (in dsn varchar, in cat varchar, in sch varchar, in table_mask varchar)
{
  declare key_list, cat_list, sch_list, tables_list any;
  declare i, len, j, lz, sz, n, is_found integer;
  declare c_cat, c_sch, m_mask, v varchar;
  cat_list:= vector();
  sch_list:= vector();

  if (cat ='%' or sch = '%')
    {
      key_list := sql_procedures (dsn, null, null, null);
    }

  if (cat ='%')
    {
      i:= 0; len :=  length (key_list);
      while (i < len)
        {
          v := aref (aref (key_list, i), 0);
          n := 0; sz := length (cat_list);
          is_found := 0;
          while(n < sz)
            {
              if (v = aref (cat_list, n) or (v is null and aref (cat_list, n) is null))
                is_found := 1;
              n := n + 1;
            }

          if (is_found = 0)
            cat_list := vector_concat (cat_list, vector (v));

          i := i + 1;
        }
    }
  else
    cat_list := vector_concat (cat_list, vector (cat));

  if (sch = '%')
    {
      i:= 0; len :=  length (key_list);
      while (i < len)
        {
          v := aref (aref (key_list, i), 1);
          n := 0; sz := length (sch_list);
          is_found := 0;

          while(n < sz)
            {
              if (v = aref (sch_list, n) or (v is null and aref (sch_list, n) is null))
                is_found := 1;
              n := n + 1;
            }

          if (is_found = 0)
            sch_list := vector_concat (sch_list, vector (v));

          i := i + 1;
        }
    }
  else
    sch_list := vector_concat (sch_list, vector (sch));

   -- now  fetch all records

   if (table_mask is not null)
     m_mask := table_mask;
   else
     m_mask := '%';
  tables_list := vector ();
  i := 0; len := length (cat_list);

  while (i < len)
    {
      c_cat := aref (cat_list, i);
      j := 0; lz := length (sch_list);

       while(j < lz)
         {
	   declare tbls any;
           c_sch := aref (sch_list, j);
	   tbls :=  sql_procedures(dsn, c_cat, c_sch, null);
	   if (m_mask = '%')
	     {
               tables_list := vector_concat (tables_list, tbls);
	     }
	   else
	     {
	       foreach (any tbl in tbls) do
		 {
		   if (length (tbl) > 1 and tbl[2] is not null and tbl[2] like m_mask)
		     {
		       tables_list := vector_concat (tables_list, vector (tbl));
		     }
		 }
	     }
           j := j + 1;
         }

       i:= i + 1;
    }
  return  tables_list;
}
;

create procedure get_vdb_data_types() {
    return vector('INTEGER','NUMERIC','DECIMAL','DOUBLE PRECISION','REAL','CHAR','CHARACTER','VARCHAR','NVARCHAR','ANY','NCHAR','SMALLINT','FLOAT','DATETIME','DATE','TIME','BINARY');
}
;

create procedure adm_is_hosted ()
{
  declare ret integer;

  ret := 0;

  if (__proc_exists ('aspx_get_temp_directory', 2) is not NULL) ret := 1;
  if (__proc_exists ('java_load_class', 2) is not NULL) ret := ret + 2;

  return ret;
}
;


create procedure
vdb_get_pkeys (in dsn varchar, in tbl_qual varchar, in tbl_user varchar, in tbl_name varchar)
  {
    declare pkeys, pkey_curr, pkey_col, my_pkeys any;
    declare pkeys_len, idx integer;

    if (length (tbl_qual) = 0)
      tbl_qual := NULL;
    if (length (tbl_user) = 0)
      tbl_user := NULL;

    if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
      {
  declare exit handler for SQLSTATE '*'
  goto next;

  pkeys := sql_primary_keys (dsn, tbl_qual, tbl_user, tbl_name);
      };
    next:

    if (not pkeys) pkeys := NULL;

    pkeys_len := length (pkeys);
    idx := 0;
    my_pkeys := vector();
    if (0 <> pkeys_len)
      {
  while (idx < pkeys_len)
    {
      pkey_curr := aref (pkeys, idx);
      pkey_col := aref (pkey_curr, 3);
      my_pkeys := vector_concat (my_pkeys, vector(pkey_col));
      idx := idx +1;
    }
      }
    else
      {
  if (sys_stat ('vdb_attach_autocommit') > 0) vd_autocommit (dsn, 1);
    {
      declare exit handler for SQLSTATE '*'
      goto next2;

      pkeys := sql_statistics (dsn, tbl_qual, tbl_user, tbl_name, 0, 1);
    };
  next2:

  if (not pkeys) pkeys := NULL;

    pkeys_len := length (pkeys);

  if (0 <> pkeys_len)
    {
      while (idx < pkeys_len)
        {
    pkey_curr := aref (pkeys, idx);
    pkey_col := aref (pkey_curr, 8);
                if (idx > 0 and aref (pkey_curr, 7) = 1 and length (my_pkeys) > 0)
                  goto key_ends;
    if (pkey_col is not null)
      my_pkeys := vector_concat (my_pkeys, vector(pkey_col));
    idx := idx +1;
        }
   key_ends:;
    }
  else
    {
      pkeys := NULL;
      pkeys_len := 0;
    }
      }

   return my_pkeys;
  }
;

yacutia_exec_no_error ('CREATE TABLE DB.DBA.SYS_REMOTE_PROCEDURES (RP_NAME varchar primary key, RP_REMOTE_NAME varchar, RP_DSN varchar)');

create procedure R_GET_REMOTE_NAME (inout pr_text any, inout rname any, inout dsn any)
{
  declare rc int;
  rname := null;
  dsn := null;
  rc := 0;

  declare exit handler for sqlstate '*'
    {
      rname := null;
      dsn := null;
      return 0;
    };

  if (regexp_match ('\-\-PL Wrapper ', pr_text) is not null)
    {
      declare tmp any;
      declare dsnofs, profs int;
      tmp := regexp_match ('\-\-"DSN:.*PROCEDURE:.*', pr_text);
      tmp := trim (tmp, '" ');
      dsnofs := strstr (tmp, '--"DSN:');
      profs := strstr (tmp, 'PROCEDURE:');
      if (dsnofs is not null and profs is not null)
        {
          dsn := subseq (tmp, dsnofs + 7, profs);
          rname := subseq (tmp, profs + 10);
          rname := trim (rname);
          dsn := trim (dsn);
    rc := 1;
        }
    }
  else if (regexp_match ('^attach procedure', lower (pr_text)) is not null)
   {
      declare exp any;
      exp := sql_parse (pr_text);
      dsn := exp[6];
      rname := exp[2];
      rc := 1;
   }
  return rc;
}
;

create procedure R_PROC_INIT ()
{
  if (registry_get ('R_PROC_INIT') = '1')
    return;
  for select P_NAME, coalesce (P_TEXT, blob_to_string (P_MORE)) as pr_text
        from DB.DBA.SYS_PROCEDURES
        where P_NAME not like '%.vsp' and
              (
         regexp_match ('^attach procedure',
     lower (coalesce (P_TEXT, blob_to_string (P_MORE)))) is not null or
               regexp_match ('\-\-PL Wrapper ', coalesce (P_TEXT, blob_to_string (P_MORE))) is not null
              ) do
    {
      declare rname, dsn varchar;

      if (R_GET_REMOTE_NAME (pr_text, rname, dsn))
  {
          insert soft  DB.DBA.SYS_REMOTE_PROCEDURES (RP_NAME, RP_REMOTE_NAME, RP_DSN)
            values (P_NAME, rname, dsn);
  }
    }
  registry_set ('R_PROC_INIT', '1');
}
;

create trigger SYS_PROCEDURES_REMOTE_AI after insert on SYS_PROCEDURES
{
  declare pr_text any;
  declare rname, dsn varchar;

  pr_text := coalesce (P_TEXT, blob_to_string (P_MORE));
  R_GET_REMOTE_NAME (pr_text, rname, dsn);
  if (R_GET_REMOTE_NAME (pr_text, rname, dsn))
    {
      insert soft  DB.DBA.SYS_REMOTE_PROCEDURES (RP_NAME, RP_REMOTE_NAME, RP_DSN)
         values (P_NAME, rname, dsn);
    }
}
;

create trigger SYS_PROCEDURES_REMOTE_AU after update on SYS_PROCEDURES
referencing old as O, new as N
{
  declare pr_text any;
  declare rname, dsn varchar;
  pr_text := coalesce (N.P_TEXT, blob_to_string (N.P_MORE));
  delete from DB.DBA.SYS_REMOTE_PROCEDURES where RP_NAME = O.P_NAME;
  if (R_GET_REMOTE_NAME (pr_text, rname, dsn))
    {
      insert soft  DB.DBA.SYS_REMOTE_PROCEDURES (RP_NAME, RP_REMOTE_NAME, RP_DSN)
         values (N.P_NAME, rname, dsn);
    }
}
;

create trigger SYS_PROCEDURES_REMOTE_AD after delete on SYS_PROCEDURES
{
  delete from DB.DBA.SYS_REMOTE_PROCEDURES where RP_NAME = P_NAME;
}
;

create procedure YAC_GET_DAV_ERR (in code int)
{
  return 'The WebDAV operation failed. Error code: ' || DAV_PERROR (code);
}
;

create procedure YAC_DAV_RES_UPLOAD
    (
    in path varchar,
    in body any,
    in tp any,
    in perms varchar,
    in own any,
    in grp any,
    in usr varchar := null
    )
{
  declare rc, flag, pwd int;

  flag := 0; pwd := null;
  if (usr is not null)
    {
      if (usr = 'dba')
        usr := 'dav';
      whenever not found goto err;
      rc := -12;
      flag := 1;
      select pwd_magic_calc (U_NAME, U_PASSWORD) into pwd from SYS_USERS where U_NAME = usr;
      rc := 0;
    }

  rc := DAV_RES_UPLOAD_STRSES_INT
        (
   path,
   body,
   tp,
   perms,
   own,
   grp,
   usr,
   pwd,
   flag
  );

err:
  if (rc <= 0)
    signal ('22023', YAC_GET_DAV_ERR (rc));
}
;

create procedure YAC_DAV_PROP_SET (in path varchar, in prop varchar, in val any, in usr varchar := null)
{
  declare rc, flag, pwd any;

  flag := 0; pwd := null;
  if (usr is not null)
    {
      if (usr = 'dba')
	usr := 'dav';
      whenever not found goto err;
      rc := -12;
      flag := 1;
      select pwd_magic_calc (U_NAME, U_PASSWORD) into pwd from SYS_USERS where U_NAME = usr;
      rc := 0;
    }
  if (flag = 0)
    usr := 'dav';

  rc := DB.DBA.DAV_PROP_SET_INT (path, prop, val, usr, pwd, flag);
err:
  if (rc <= 0)
    signal ('22023', YAC_GET_DAV_ERR (rc));
}
;

create procedure YAC_DAV_PROP_REMOVE (in path varchar, in prop varchar, in usr varchar, in silent int := 0)
{
  declare rc, flag, pwd any;

  pwd := null;
  whenever not found goto err;
  if (usr = 'dba')
    usr := 'dav';
  rc := -12;
  select pwd_magic_calc (U_NAME, U_PASSWORD) into pwd from SYS_USERS where U_NAME = usr;
  rc := 0;
  rc := DB.DBA.DAV_PROP_REMOVE (path, prop, usr, pwd);
err:
  if (rc < 0 and silent = 0)
    signal ('22023', YAC_GET_DAV_ERR (rc));
}
;

create procedure www_split_host (in fhost any, out host any, out port any)
{
  declare pos int;
  pos := strrchr (fhost, ':');
  if (pos is not null)
    {
      host := substring (fhost, 1, pos);
      port := substring (fhost, pos + 2, length (fhost));
    }
  else
    {
      host := fhost;
      if (host not in ('*ini*', '*sslini*'))
        port := '80';
    }
}
;

create procedure www_tree (in path any)
{
  declare ss, i any;
  ss := string_output ();
  http ('<www>', ss);
  for select distinct HP_HOST as HOST, HP_LISTEN_HOST as LHOST,

    (case HP_HOST when '*ini*' then 0 when '*sslini*' then 0
    else 1 end) as HP_NO_EDIT,

    (case HP_LISTEN_HOST when '*ini*' then 0 when '*sslini*' then 0
    when (':' || cfg_item_value (virtuoso_ini_path(), 'HTTPServer', 'SSLPort')) then 0
    else 1 end) as HP_NO_CTRL

      from DB.DBA.HTTP_PATH order by HOST, LHOST do
     {
       declare vhost, intf, port, tmp any;

       vhost := HOST;
       intf := LHOST;
       port := '';


       if (vhost = '*ini*')
   {
     vhost := '{Default Web Site}';
     port := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'ServerPort');
     intf := '0.0.0.0';
   }
       else if (vhost = '*sslini*')
   {
           vhost := '{Default SSL Web Site}';
     port := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'SSLPort');
     if (port is null)
       port := '';
     intf := '0.0.0.0';
   }
       else
   {
     www_split_host (HOST, vhost, tmp);
     www_split_host (LHOST, intf, port);
     if (intf = '' or intf = '*ini*' or intf = '*sslini*')
       {
	   if (intf = '*ini*')
	     port := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'ServerPort');
	   else if (intf = '*sslini*')
	     port := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'SSLPort');
       intf := '0.0.0.0';
   }
   }


       http (sprintf ('<node host="%s" port="%s" lhost="%s" edit="%d" chost="%s" clhost="%s" control="%d">\n', vhost, port, intf, HP_NO_EDIT, HOST, LHOST, HP_NO_CTRL), ss);
       i := 0;
       for select HP_LPATH, HP_PPATH, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_SECURITY from DB.DBA.HTTP_PATH where HP_HOST = HOST and HP_LISTEN_HOST = LHOST do
   {
      declare tp, usr any;
      if (HP_PPATH like '/DAV/%')
        tp := 'DAV';
      else if (HP_PPATH like '/SOAP/%' or HP_PPATH = '/SOAP')
        tp := 'SOAP';
      else if (HP_PPATH like '/INLINEFILE/%')
        tp := 'INL';
      else
        tp := 'FS';

        if (tp = 'SOAP' and length (HP_RUN_SOAP_AS))
    usr := HP_RUN_SOAP_AS;
          else if (length (HP_RUN_VSP_AS))
    usr := HP_RUN_VSP_AS;
        else
          usr := '*disabled*';

      if (path = '*ALL*' or path = tp)
        {
                http (sprintf ('\t<node lpath="%s" type="%s" user="%s" sec="%s"/>\n', HP_LPATH, tp, usr, HP_SECURITY), ss);
    i := i + 1;
        }
   }
       if (not i)
   http (sprintf ('\t<node />\n'), ss);
       http ('</node>\n', ss);
     }
  http ('</www>', ss);
  return xtree_doc (ss);
}
;


create procedure www_root_node (in path any)
{
  return xpath_eval ('/www/*', www_tree (path), 0);
}
;


create procedure www_chil_node (in path varchar, in node varchar)
{
  return xpath_eval (path, node, 0);
}
;

create procedure y_get_host_name (in vhost varchar, in port varchar, in lines varchar)
{
  declare host, hpa any;

  host := http_request_header (lines, 'Host', null, sys_connected_server_address ());
  if (vhost = '*ini*' or vhost = '*sslini*' or vhost[0] = ascii (':') or length (vhost) = 0)
    hpa := split_and_decode (host, 0, '\0\0:');
  else
    hpa := split_and_decode (vhost, 0, '\0\0:');
  return hpa[0] || ':' || port;
}
;


create procedure y_base_uri (in p any)
{
  declare path any;
  path := http_physical_path ();
  path := WS.WS.EXPAND_URL (path, p);
  if (path like '/DAV/%')
    path := 'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:' || path;
  else
    path := 'file:' || path;
  return path;
}
;

create procedure y_get_file_dsns ()
{
  declare arr, pwd, dsns any;
  pwd := server_root ();
  dsns := vector ();
  if (not (sys_stat('st_build_opsys_id') = 'Win32'))
    goto done;
  declare exit handler for sqlstate '*'
  {
    goto done;
  };
  arr := sys_dirlist ('.', 1);
  foreach (any elm in arr) do
   {
     if (elm like '%.dsn')
       dsns := vector_concat (dsns, vector (vector (pwd || elm, '')));
   }
  done:
  return dsns;
}
;

create procedure get_granted_xml_templates (in uid int, inout plist any)
{
  declare arr any;
  arr := vector ();
  plist := vector ();
  for select G_OBJECT from SYS_GRANTS where G_OP = 32 and G_USER = uid do
    {
      for select blob_to_string (PROP_VALUE) as PROP_VALUE, RES_FULL_PATH
  from WS.WS.SYS_DAV_PROP, WS.WS.SYS_DAV_RES
  where PROP_TYPE = 'R' and PROP_NAME = 'xml-soap-method' and RES_ID = PROP_PARENT_ID do
    {
      if (PROP_VALUE = G_OBJECT)
        {
          arr := vector_concat (arr, vector (RES_FULL_PATH));
          plist := vector_concat (plist, vector (G_OBJECT));
          goto next;
              }
    }
      next:;
    }
  return arr;
}
;

create procedure grant_xml_template (in path varchar, in uname varchar)
{
  declare p_name any;
  p_name := make_xml_template_wrapper (path, uname, 1);
  exec (sprintf ('GRANT EXECUTE ON %s to "%s"', p_name, uname));
}
;

create procedure revoke_xml_template (in path varchar, in uname varchar)
{
  declare p_name any;
  p_name := make_xml_template_wrapper (path, uname, 0);
  if (p_name is not null)
    exec (sprintf ('REVOKE EXECUTE ON %s FROM "%s"', p_name, uname));
}
;

create procedure make_xml_template_wrapper (in path varchar, in uname varchar, in make_proc int := 1)
{
   declare n_name, proc_text, tp_name varchar;
   declare e_stat, e_msg, ext_type varchar;
   declare res_id integer;
   declare res_cnt varchar;
   declare descr varchar;
   declare xm any;
   declare exist_pr varchar;
   declare prop_v varchar;

   n_name := SYS_ALFANUM_NAME (path);
   ext_type := '';
   e_stat := '00000';

   if (strchr (n_name, '.') is null)
     tp_name := concat ('"XT"."', uname, '"."', n_name, '"');
   else
     tp_name := n_name;

   whenever not found goto err;
   select blob_to_string (RES_CONTENT), RES_ID into res_cnt, res_id from WS.WS.SYS_DAV_RES where RES_FULL_PATH = path;
   descr := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP where
      PROP_NAME = 'xml-sql-description' and PROP_TYPE= 'R' and PROP_PARENT_ID = res_id), '');
   exist_pr := coalesce ((select blob_to_string (PROP_VALUE) from WS.WS.SYS_DAV_PROP
      where PROP_NAME = 'xml-soap-method' and PROP_TYPE = 'R' and PROP_PARENT_ID = res_id), tp_name);

   if (__proc_exists (exist_pr) is not null)
     {
       tp_name := sprintf ('"%I"."%I"."%I"',
       name_part (exist_pr, 0), name_part (exist_pr, 1), name_part (exist_pr, 2));
       goto ret;
     }
   else if (not make_proc)
     return null;

   xm := cast (xpath_eval ('local-name (/*[1])', xml_tree_doc (res_cnt)) as varchar);

   ext_type := sprintf (' returns xmltype __soap_options (__soap_type:=\'__VOID__\',PartName:=\'%s\')', xm);

   if (descr <> '')
     descr := concat ('\n--##', descr, '\n');


   proc_text := sprintf ('CREATE PROCEDURE %s () %s \n{', tp_name, ext_type);
   proc_text := concat (proc_text, descr, 'declare temp, content any;\n temp := string_output ();\n');
   proc_text := concat (proc_text, '\n if (exists (select 1 from WS.WS.SYS_DAV_RES where RES_ID = ',
     cast (res_id as varchar),'))\n   select RES_CONTENT into content from WS.WS.SYS_DAV_RES ',
     'where RES_ID = ', cast (res_id as varchar), ';\n',
     '  else \n  return NULL;\n xml_template (xml_tree_doc (content),',
     'vector (), temp); \n',
     'return xml_tree_doc (string_output_string (temp)); }\n\n');


   if (strchr (n_name, '.') is null)
     prop_v := sprintf ('XT.%s.%s', uname, n_name);
   else
     prop_v := n_name;

   exec (proc_text, e_stat, e_msg);
   YAC_DAV_PROP_SET (path, 'xml-soap-method', prop_v);

   ret:
   return tp_name;
   err:
   if (e_stat = '00000')
     {
       e_stat := 'XT000';
       e_msg := 'No such resource';
     }
   signal (e_stat, e_msg);
}
;

/*
  SQL-XML or SQLX detection
*/

create procedure y_check_query_type (in query_text any)
{
  declare lexems, i, lex_text, len, flag, pos any;

  lexems := sql_lex_analyze (query_text);
  len := length (lexems);
  flag := -2; -- SQLX case
  i :=  length (aref (lexems, len - 1));
  if (i = 3 and len > 3)
    {
      pos := 0;
      i := len - 1;
      while (i >= 0)
        {
          lex_text := upper (aref (aref (lexems, i), 1));
          if ((lex_text = 'RAW' or lex_text = 'AUTO' or lex_text = 'EXPLICIT' ) and flag = -2)
            {
	      flag := 4;
	      pos := i;
            }

          if (lex_text = 'XML' and flag = 4 and pos = (i + 1))
            {
	      flag := 3;
            }
          else if (lex_text = 'FOR' and flag = 3 and pos = (i + 2))
	      {
		flag := 2;
	      }
	  else if (lex_text = 'XMLELEMENT' and flag = -2)
	    {
	      flag := 0;
	    }
          i := i - 1;
        }
      if (flag <> 0 and flag <> 2 and upper (aref (aref (lexems, 0), 1)) = 'SELECT')
	flag := 2;
    }
  return flag;
};

create procedure y_execute_xq (in q any, in root any, in base any, in url any, in ctx any, in pmode any)
{
  declare doc, res, nuri, coll any;
  declare ses any;

  ctx := atoi (ctx);
  if (ctx = 0)
    doc := xtree_doc('<empty/>', atoi (pmode), base);
  else if (ctx <> 4)
    {
      nuri := DB.DBA.XML_URI_RESOLVE_LIKE_GET (base, url);
      doc := DB.DBA.XML_URI_GET ('', nuri);
      if (not isentity (doc))
        doc := xtree_doc (doc, atoi (pmode), nuri);
    }
  else
    {
      nuri := DB.DBA.XML_URI_RESOLVE_LIKE_GET (base, url);
      coll := xquery_eval (sprintf ('<%s>{ for \044doc in collection ("%s",.,1,2) return \044doc/* }</%s>',
      		root, nuri, root), xtree_doc('<empty/>', 0, nuri), 0);
      doc := coll[0];
    }
  res := xquery_eval (q, doc, 0);
  ses := string_output ();
  foreach (any elm in res) do
    {
      --dbg_obj_print (xml_tree_doc_media_type (elm));
      if (isentity (elm))
        {
	  xml_tree_doc_set_output (elm, 'xml');
	  http_value (elm, null, ses);
        }
    }
  return string_output_string (ses);
}
;


create procedure y_cli_status_proc ()
{
  declare stat, msg, dta, mta any;
  declare name varchar;
  declare bin, bout, threads, st int;

  commit work;
  result_names (name, bin, bout, threads);
  stat := '00000';
  exec ('status (\'c\')', stat, msg, vector (), 1000, mta, dta);

  if (stat <> '00000')
    {
      rollback work;
      return;
    }
  st := 0;
  foreach (any elm in dta) do
    {
      declare tmp1, tmp2, tmp3, tmp4, line any;
      line := elm[0];
      if (st = 0)
        {
	  tmp1 := regexp_match ('Account: [[:alnum:]_]+', line);
	  tmp2 := regexp_match ('[0-9]+ bytes in', line);
	  tmp3 := regexp_match ('[0-9]+ bytes out', line);
	  if (tmp1 is not null and tmp2 is not null and tmp3 is not null)
	    {
	      name := substring (tmp1, 9, length (tmp1));
	      bin := atoi(tmp2);
	      bout := atoi(tmp3);
	      st := 1;
	    }
	}
      else if (st = 1)
	{
	  tmp4 := regexp_match ('[0-9]+ threads\.', line);
	  if (tmp4 is not null)
	    {
	      threads := atoi (tmp4);
	      result (name, bin, bout, threads);
	    }
	  st := 0;
	}
    }
}
;

yacutia_exec_no_error('drop view DB.DBA.CLI_STATUS_REPORT');

create procedure view CLI_STATUS_REPORT as y_cli_status_proc () (name varchar, bin int, bout int, threads int);



create procedure check_package (in pname varchar)
{
  if (vad_check_version (pname) is null)
    return 0;
  return 1;
}
;

create procedure y_check_if_bit (inout bits any, in bit int)
{
  if (bits[bit] = ascii ('1'))
    return 'checked';
  return '';
}
;


/* HTTP port check */
create procedure y_check_host (in host varchar, in listen varchar, in port varchar)
{
  declare inihost, ihost, iport varchar;
  declare pos int;

  inihost := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'ServerPort');

  pos := strrchr (inihost, ':');

  if (pos is not null)
    {
      ihost := substring (inihost, 1, pos);
      iport := substring (inihost, pos + 2, length (inihost));
    }
  else if (atoi (inihost))
    {
      ihost := '';
      iport := inihost;
    }
  else
    {
      ihost := inihost;
      iport := '80';
    }

  if (ihost = '0.0.0.0')
    ihost := '';

  if (listen = '0.0.0.0')
    listen := '';

  if (not length (port))
    port := '80';

  if (port = iport and host = ihost)
    signal ('22023', 'The default listener and host are configurable via INI file only');

}
;

create procedure y_make_url_from_vd (in host varchar, in lhost varchar, in path varchar)
{
  declare pos, port any;
  pos := strrchr (host, ':');
  if (pos is not null)
    host := subseq (host, 0, pos);
  pos := strrchr (lhost, ':');
  if (pos is not null)
    port := subseq (lhost, pos, length (lhost));
  else if (lhost = '*ini*')
    port := ':'||server_http_port ();
  else
    port := '';
  return sprintf ('http://%s%s%s/', host, port, rtrim(path, '/'));
};

create procedure y_escape_local_name (in nam varchar)
{
  declare q, o, n varchar;
  if (nam is null or nam[0] = ascii ('"'))
    return nam;
  q := name_part (nam, 0);
  o := name_part (nam, 1);
  n := name_part (nam, 2);
  return sprintf ('"%I"."%I"."%I"', q, o, n);
}
;

create procedure y_get_tbl_row_count (in q any, in o any, in n any)
{
  declare stat, msg, dta, mdta any;
  stat := '00000';
  exec (sprintf ('select count(*) from "%I"."%I"."%I"', q, o, n), stat, msg, vector (), 0, mdta, dta);
  if (stat = '00000')
    return dta[0][0];
  return 0;
}
;

create procedure y_get_first_table_name (in q any)
{
   declare tree, tbn any;
   tree := sql_parse (q);
   tbn := '';
   y_get_first_table (tree, tbn);
   return tbn;
}
;

create procedure y_get_first_table (in tree any, inout tbn any)
{
  if (isarray (tree) and length (tree) > 1 and tree[0] = 200)
    {
      if (length (tbn))
	tbn := tbn || '_' ;
      tbn := tbn || name_part (tree[1], 2);
      return;
    }
  else if (isarray (tree))
    {
      foreach (any tree1 in tree) do
	{
	  y_get_first_table (tree1, tbn);
	}
    }
}
;

create procedure y_make_tb_from_query (in tb any, in q any)
{
  declare stat, msg, meta any;
  declare stmt varchar;

  stat := '00000';
  exec_metadata (q, stat, msg, meta);
  if (stat <> '00000')
    signal (stat, msg);
  if (not isarray (meta))
    signal ('22023', 'Invalid query');

  tb := complete_table_name  (tb, 1);
  stmt := sprintf ('create table "%I"."%I"."%I" (',
  		name_part (tb,0),
  		name_part (tb,1),
  		name_part (tb,2));

  foreach (any col in meta[0]) do
    {
      declare col_name, col_type, col_tb, org_col varchar;
      declare dt int;
      -- ("ID" 189 0 10 1 1 1 "DB" "WAI_ID" "DBA" "WA_INSTANCE" 2 )
      col_tb := sprintf ('%s.%s.%s', col[7], col[9], col[10]);
      org_col := col[8];
      col_name := col[0];
      dt := col[1];
      if (dt = 254)
        {
	  col_type := (SELECT get_keyword('sql_class',COL_OPTIONS)
	    FROM DB.DBA.SYS_COLS WHERE "TABLE" = col_tb AND "COLUMN" = org_col);
	}
      else
        {
	  col_type := REPL_COLTYPE (col);
        }
      if (isnull (col_type))
	signal('Error', sprintf('Counld not find column type for column: %s', org_col));
      stmt := concat (stmt, col_name, ' ', col_type);
      stmt := concat (stmt, ', ');
    }
   stmt := rtrim (stmt, ', ');
   stmt := concat (stmt, ')');
   return stmt;
}
;

