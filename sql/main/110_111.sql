begin;
insert into sys.version(number,comment) values(111,'Load balancing');


CREATE OR REPLACE FUNCTION switch12.process_dp(
  i_profile switch12.callprofile54_ty,
  i_destination class4.destinations,
  i_dp class4.dialpeers,
  i_customer_acc billing.accounts,
  i_customer_gw class4.gateways,
  i_vendor_acc billing.accounts,
  i_pop_id integer,
  i_send_billing_information boolean,
  i_max_call_length integer)
  RETURNS SETOF switch12.callprofile54_ty AS
$BODY$
DECLARE
  /*dbg{*/
  v_start timestamp;
  v_end timestamp;
  /*}dbg*/
  v_gw class4.gateways%rowtype;
BEGIN
  /*dbg{*/
  v_start:=now();
  --RAISE NOTICE 'process_dp in: %',i_profile;5
  v_end:=clock_timestamp();
  RAISE NOTICE '% ms -> process-DP. Found dialpeer: %',EXTRACT(MILLISECOND from v_end-v_start),row_to_json(i_dp,true);
  /*}dbg*/

  --RAISE NOTICE 'process_dp dst: %',i_destination;
  if i_dp.gateway_id is null then
    PERFORM id from class4.gateway_groups where id=i_dp.gateway_group_id and prefer_same_pop;
    IF FOUND THEN
      /*rel{*/
      FOr v_gw in  select * from class4.gateways cg where cg.gateway_group_id=i_dp.gateway_group_id and cg.contractor_id=i_dp.vendor_id and cg.enabled ORDER BY cg.pop_id=i_pop_id desc,cg.priority desc, random() LOOP
        return query select * from process_gw_release(i_profile, i_destination, i_dp, i_customer_acc,
                                                      i_customer_gw, i_vendor_acc , v_gw, i_send_billing_information,i_max_call_length);
      end loop;
      /*}rel*/
      /*dbg{*/
      FOr v_gw in  select * from class4.gateways cg where cg.gateway_group_id=i_dp.gateway_group_id AND cg.enabled ORDER BY cg.pop_id=i_pop_id desc,cg.priority desc, random() LOOP
        IF v_gw.contractor_id!=i_dp.vendor_id THEN
          RAISE WARNING 'process_dp: Gateway owner !=dialpeer owner. Skip gateway';
          continue;
        end if;
        return query select * from process_gw_debug(i_profile, i_destination, i_dp, i_customer_acc,
                                                    i_customer_gw, i_vendor_acc , v_gw, i_send_billing_information,i_max_call_length);
      end loop;
      /*}dbg*/
    else
      /*rel{*/
      FOr v_gw in  select * from class4.gateways cg where cg.gateway_group_id=i_dp.gateway_group_id and cg.contractor_id=i_dp.vendor_id AND cg.enabled ORDER BY cg.priority desc, random() LOOP
        return query select * from process_gw_release(i_profile, i_destination, i_dp, i_customer_acc,
                                                      i_customer_gw, i_vendor_acc , v_gw, i_send_billing_information,i_max_call_length);
      end loop;
      /*}rel*/
      /*dbg{*/
      FOr v_gw in  select * from class4.gateways cg where cg.gateway_group_id=i_dp.gateway_group_id and cg.enabled ORDER BY cg.priority desc, random() LOOP
        IF v_gw.contractor_id!=i_dp.vendor_id THEN
          RAISE WARNING 'process_dp: Gateway owner !=dialpeer owner. Skip gateway';
          continue;
        end if;
        return query select * from process_gw_debug(i_profile, i_destination, i_dp, i_customer_acc,
                                                    i_customer_gw, i_vendor_acc , v_gw, i_send_billing_information,i_max_call_length);
      end loop;
      /*}dbg*/
    end if;
  else
    select into v_gw * from class4.gateways cg where cg.id=i_dp.gateway_id and cg.enabled;
    if FOUND THEN
      IF v_gw.contractor_id!=i_dp.vendor_id THEN
        RAISE WARNING 'process_dp: Gateway owner !=dialpeer owner. Stop processing';
        return;
      end if;

      /*rel{*/
      return query select * from
          process_gw_release(i_profile, i_destination, i_dp, i_customer_acc,i_customer_gw, i_vendor_acc, v_gw, i_send_billing_information,i_max_call_length);
      /*}rel*/
      /*dbg{*/
      return query select * from
          process_gw_debug(i_profile, i_destination, i_dp, i_customer_acc,i_customer_gw, i_vendor_acc, v_gw, i_send_billing_information,i_max_call_length);
      /*}dbg*/
    else
      return;
    end if;
  end if;
END;
$BODY$
LANGUAGE plpgsql STABLE SECURITY DEFINER
COST 10000
ROWS 1000;


DROP FUNCTION switch12.debug(smallint, inet, integer, character varying, character varying, integer, character varying, character varying, character varying, character varying);

CREATE OR REPLACE FUNCTION switch12.debug(
  i_transport_protocol_id smallint,
  i_remote_ip inet,
  i_remote_port integer,
  i_src_prefix character varying,
  i_dst_prefix character varying,
  i_pop_id integer,
  i_uri_domain character varying,
  i_from_domain character varying,
  i_to_domain character varying,
  i_x_yeti_auth character varying,
  i_release_mode boolean default false
)
  RETURNS SETOF switch12.callprofile54_ty AS
$BODY$
DECLARE
  v_r record;
  v_start  timestamp;
  v_end timestamp;
BEGIN
  set local search_path to switch12,sys,public;
  v_start:=now();
  v_end:=clock_timestamp(); /*DBG*/
  RAISE NOTICE '% ms -> DBG. Start',EXTRACT(MILLISECOND from v_end-v_start); /*DBG*/
  if i_release_mode then
    return query SELECT * from route_release(
        1,              --i_node_id
        i_pop_id,              --i_pop_id
        i_transport_protocol_id,
        i_remote_ip::inet,
        i_remote_port::int,
        '127.0.0.1'::inet,    --i_local_ip
        '5060'::int,         --i_local_port
        'from_name'::varchar,
        i_src_prefix::varchar,   --i_from_name
        i_from_domain,
        '5060'::int,         --i_from_port
        i_dst_prefix::varchar,   --i_to_name
        i_to_domain,
        '5060'::int,         --i_to_port
        i_src_prefix::varchar,   --i_contact_name
        i_remote_ip::varchar,    --i_contact_domain
        i_remote_port::int,  --i_contact_port
        i_dst_prefix::varchar,   --i_user,
        i_uri_domain::varchar,   -- URI domain
        i_x_yeti_auth::varchar,            --i_headers,
        NULL, --diversion
        NULL, --X-ORIG-IP
        NULL, --X-ORIG-PORT
        NULL -- X-ORIG-PROTO
    );
  else
    return query SELECT * from route_debug(
        1,              --i_node_id
        i_pop_id,              --i_pop_id
        i_transport_protocol_id,
        i_remote_ip::inet,
        i_remote_port::int,
        '127.0.0.1'::inet,    --i_local_ip
        '5060'::int,         --i_local_port
        'from_name'::varchar,
        i_src_prefix::varchar,   --i_from_name
        i_from_domain,
        '5060'::int,         --i_from_port
        i_dst_prefix::varchar,   --i_to_name
        i_to_domain,
        '5060'::int,         --i_to_port
        i_src_prefix::varchar,   --i_contact_name
        i_remote_ip::varchar,    --i_contact_domain
        i_remote_port::int,  --i_contact_port
        i_dst_prefix::varchar,   --i_user,
        i_uri_domain::varchar,   -- URI domain
        i_x_yeti_auth::varchar,            --i_headers,
        NULL, --diversion
        NULL, --X-ORIG-IP
        NULL, --X-ORIG-PORT
        NULL -- X-ORIG-PROTO
    );
  end if;
END;
$BODY$
LANGUAGE plpgsql VOLATILE SECURITY DEFINER
COST 100
ROWS 10;

set search_path TO switch12;
SELECT * from preprocess_all();

commit;


