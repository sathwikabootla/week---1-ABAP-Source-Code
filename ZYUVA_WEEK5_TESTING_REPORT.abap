CLASS zcl_supply_chain_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .
    PUBLIC SECTION.
    TYPES: BEGIN OF ty_inventory_movement,
             matnr TYPE matnr,
             werks TYPE werks_d,
             lgort TYPE lgort_d,
             menge TYPE menge_d,
             meins TYPE meins,
             waers TYPE waers,
             dmbtr TYPE dmbtr,
           END OF ty_inventory_movement.
TYPES: BEGIN OF ty_validation_result,
             is_valid TYPE abap_bool,
             message  TYPE string,
           END OF ty_validation_result.
METHODS:
      validate_movement_data
        IMPORTING
          is_movement      TYPE ty_inventory_movement
        RETURNING
          VALUE(rs_result) TYPE ty_validation_result,
      calculate_allocation
        IMPORTING
          is_movement            TYPE ty_inventory_movement
        RETURNING
          VALUE(rv_alloc_quant)  TYPE menge_d
        RAISING
          cx_sy_zerodivide,
       post_financial_ledger
        IMPORTING
          is_movement       TYPE ty_inventory_movement
          iv_allocated_qty  TYPE menge_d
        RETURNING
          VALUE(rv_success) TYPE abap_bool.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.
CLASS zcl_supply_chain_engine IMPLEMENTATION.
METHOD validate_movement_data.
    CLEAR rs_result.
    rs_result-is_valid = abap_true.
IF is_movement-matnr IS INITIAL OR is_movement-werks IS INITIAL.
      rs_result-is_valid = abap_false.
      rs_result-message  = 'Material number and Plant are mandatory fields.'.
      RETURN.
    ENDIF.
IF is_movement-menge <= 0.
      rs_result-is_valid = abap_false.
      rs_result-message  = 'Movement quantity must be strictly greater than zero.'.
      RETURN.
    ENDIF.
  ENDMETHOD.
METHOD calculate_allocation.
    IF is_movement-menge = 0.
      RAISE EXCEPTION TYPE cx_sy_zerodivide.
    ENDIF.
    rv_alloc_quant = is_movement-menge * '0.15'.
  ENDMETHOD.
METHOD post_financial_ledger.
    DATA: lv_subrc TYPE sysubrc VALUE 0.
IF is_movement-dmbtr IS INITIAL OR is_movement-waers IS INITIAL.
      rv_success = abap_false.
      RETURN.
    ENDIF.
IF lv_subrc = 0.
      rv_success = abap_true.
    ELSE.
      rv_success = abap_false.
    ENDIF.
  ENDMETHOD.
ENDCLASS.
CLASS lcl_test_supply_chain DEFINITION FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.
PRIVATE SECTION.
    DATA: f_cut TYPE REF TO zcl_supply_chain_engine.
METHODS:
      setup,
      test_valid_data_handling     FOR TESTING,
      test_invalid_zero_quantity   FOR TESTING,
      test_allocation_calculation  FOR TESTING,
      test_ledger_integration_fail FOR TESTING.

ENDCLASS.
CLASS lcl_test_supply_chain IMPLEMENTATION.
METHOD setup.
    " Instantiate the Class Under Test (CUT) before each test execution
    CREATE OBJECT f_cut.
  ENDMETHOD.
METHOD test_valid_data_handling.
    DATA: ls_move   TYPE zcl_supply_chain_engine=>ty_inventory_movement,
          ls_result TYPE zcl_supply_chain_engine=>ty_validation_result.
    ls_move-matnr = 'MAT-10092'.
    ls_move-werks = '1010'.
    ls_move-lgort = '0001'.
    ls_move-menge = 100.
    ls_move-meins = 'PC'.
ls_result = f_cut->validate_movement_data( ls_move ).
cl_abap_unit_assert=>assert_equals(
      act   = ls_result-is_valid
      exp   = abap_true
      msg   = 'Valid movement data structure rejected incorrectly.' ).
  ENDMETHOD.
METHOD test_invalid_zero_quantity.
    DATA: ls_move   TYPE zcl_supply_chain_engine=>ty_inventory_movement,
          ls_result TYPE zcl_supply_chain_engine=>ty_validation_result.
ls_move-matnr = 'MAT-10092'.
    ls_move-werks = '1010'.
    ls_move-menge = 0.
ls_result = f_cut->validate_movement_data( ls_move ).
cl_abap_unit_assert=>assert_equals(
      act   = ls_result-is_valid
      exp   = abap_false
      msg   = 'Zero or negative quantity passed validation checks unexpectedly.' ).
  ENDMETHOD.
METHOD test_allocation_calculation.
    DATA: ls_move        TYPE zcl_supply_chain_engine=>ty_inventory_movement,
          lv_alloc_quant TYPE menge_d.
ls_move-menge = 200.
TRY.
        lv_alloc_quant = f_cut->calculate_allocation( ls_move ).
        cl_abap_unit_assert=>assert_equals(
          act   = lv_alloc_quant
          exp   = 30
          msg   = 'The dynamic safety buffer allocation calculated an unexpected value.' ).
      CATCH cx_sy_zerodivide.
        cl_abap_unit_assert=>fail( msg = 'System encountered unexpected division by zero exception.' ).
    ENDTRY.
  ENDMETHOD.
METHOD test_ledger_integration_fail.
    DATA: ls_move    TYPE zcl_supply_chain_engine=>ty_inventory_movement,
          lv_success TYPE abap_bool.
ls_move-matnr = 'MAT-10092'.
    ls_move-menge = 50.
    ls_move-dmbtr = 0.
    ls_move-waers = ' '.
lv_success = f_cut->post_financial_ledger(
      is_movement      = ls_move
      iv_allocated_qty = 5 ).
cl_abap_unit_assert=>assert_equals(
      act   = lv_success
      exp   = abap_false
      msg   = 'Financial ledger interface accepted an invalid integration payload without currency parameters.' ).
  ENDMETHOD.
ENDCLASS.
