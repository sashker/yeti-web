begin;
insert into sys.version(number,comment) values(100,'Skip termination to gateways of another vendor');

CREATE OR REPLACE FUNCTION switch11.process_dp(
  i_profile switch11.callprofile51_ty,
  i_destination class4.destinations,
  i_dp class4.dialpeers,
  i_customer_acc billing.accounts,
  i_customer_gw class4.gateways,
  i_vendor_acc billing.accounts,
  i_pop_id integer,
  i_send_billing_information boolean,
  i_max_call_length integer)
  RETURNS SETOF switch11.callprofile51_ty AS
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
      FOr v_gw in  select * from class4.gateways cg where cg.gateway_group_id=i_dp.gateway_group_id and cg.contractor_id=i_dp.vendor_id and cg.enabled ORDER BY cg.pop_id=i_pop_id desc,cg.priority desc LOOP
        return query select * from process_gw_release(i_profile, i_destination, i_dp, i_customer_acc,
                                                      i_customer_gw, i_vendor_acc , v_gw, i_send_billing_information,i_max_call_length);
      end loop;
      /*}rel*/
      /*dbg{*/
      FOr v_gw in  select * from class4.gateways cg where cg.gateway_group_id=i_dp.gateway_group_id AND cg.enabled ORDER BY cg.pop_id=i_pop_id desc,cg.priority desc LOOP
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
      FOr v_gw in  select * from class4.gateways cg where cg.gateway_group_id=i_dp.gateway_group_id and cg.contractor_id=i_dp.vendor_id AND cg.enabled ORDER BY cg.priority desc LOOP
        return query select * from process_gw_release(i_profile, i_destination, i_dp, i_customer_acc,
                                                      i_customer_gw, i_vendor_acc , v_gw, i_send_billing_information,i_max_call_length);
      end loop;
      /*}rel*/
      /*dbg{*/
      FOr v_gw in  select * from class4.gateways cg where cg.gateway_group_id=i_dp.gateway_group_id and cg.enabled ORDER BY cg.priority desc LOOP
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


set search_path TO switch11;
select * from preprocess_all();

commit;
