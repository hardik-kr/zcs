CLASS lhc_Bus DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS changeOnCreate FOR DETERMINE ON SAVE
      IMPORTING keys FOR Bus~changeOnCreate.

    METHODS changeOnDelete FOR DETERMINE ON SAVE
      IMPORTING keys FOR Bus~changeOnDelete.

    METHODS changeOnUpdate FOR DETERMINE ON SAVE
      IMPORTING keys FOR Bus~changeOnUpdate.

ENDCLASS.

CLASS lhc_Bus IMPLEMENTATION.

  METHOD changeOnCreate.

*   Generating Bus Id
    SELECT SINGLE * FROM zvalue
        WHERE row_number = 1
        INTO @DATA(values).

    DATA new_bus_id TYPE INT8.
    new_bus_id = values-bus_id + 1.

    UPDATE zvalue SET bus_id = @new_bus_id
    WHERE row_number = 1.

    DATA bus_id TYPE STRING.
    bus_id = new_bus_id.

    MODIFY ENTITIES OF zi_bus_g4 IN LOCAL MODE
      ENTITY Bus
        UPDATE
          FIELDS ( BusId )
          WITH VALUE #( FOR key in keys
                        ( %tky = key-%tky
                          BusId = bus_id
                           ) ).
  ENDMETHOD.

  METHOD changeOnDelete.
    READ ENTITIES OF zi_bus_g4 IN LOCAL MODE
      ENTITY Bus
        FIELDS ( BusId ) WITH CORRESPONDING #( keys )
      RESULT DATA(buses).

    LOOP AT buses INTO DATA(bus).
        DELETE FROM ztravel_g4 WHERE bus_id = @bus-BusId.
        DELETE FROM zbooking_g4 WHERE bus_id = @bus-BusId.
    ENDLOOP.

  ENDMETHOD.

  METHOD changeOnUpdate.
  ENDMETHOD.

ENDCLASS.
