CLASS lhc_Booking DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.


    METHODS changeBusStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Booking~changeBusStatus.

    METHODS changeTravel FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Booking~changeTravel.

    METHODS validateAge FOR VALIDATE ON SAVE
      IMPORTING keys FOR Booking~validateAge.
    METHODS changeOnCreate FOR DETERMINE ON SAVE
      IMPORTING keys FOR Booking~changeOnCreate.
    METHODS validatePhoneNumber FOR VALIDATE ON SAVE
      IMPORTING keys FOR Booking~validatePhoneNumber.
    METHODS startDate FOR VALIDATE ON SAVE
      IMPORTING keys FOR Booking~startDate.
    METHODS onCancellation FOR DETERMINE ON SAVE
      IMPORTING keys FOR Booking~onCancellation.

ENDCLASS.

CLASS lhc_Booking IMPLEMENTATION.

  METHOD changeBusStatus.
    READ ENTITIES OF zi_booking_g4 IN LOCAL MODE
      ENTITY Booking
        FIELDS ( BusId ) WITH CORRESPONDING #( keys )
      RESULT DATA(bookings).

    LOOP AT bookings INTO DATA(booking).

      SELECT SINGLE * FROM zbus_g4
      WHERE bus_id = @booking-BusId
      INTO @DATA(bus).

      MODIFY ENTITIES OF zi_booking_g4 IN LOCAL MODE
          ENTITY Booking
            UPDATE
              FIELDS ( BusName Source Destination DepartureTime Duration Fare )
              WITH VALUE #(
                            ( %tky         = booking-%tky
                              BusName = bus-bus_name
                              Source = bus-source
                              Destination = bus-destination
                              DepartureTime = bus-departure_time
                              Duration = bus-duration
                              Fare = bus-fare
                              ) ).

    ENDLOOP.

  ENDMETHOD.





  METHOD changeTravel.
    READ ENTITIES OF zi_booking_g4 IN LOCAL MODE
      ENTITY Booking
        FIELDS ( BusId StartDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(travels).
    LOOP AT travels INTO DATA(travel).
      SELECT COUNT( * ) FROM ztravel_g4
      WHERE bus_id = @travel-BusId AND start_date = @travel-StartDate
      INTO @DATA(count_rows).
      IF count_rows > 0.
        SELECT SINGLE * FROM ztravel_g4
        WHERE bus_id = @travel-BusId AND start_date = @travel-StartDate
        INTO @DATA(travel_data).

        IF travel_data-empty_seats > 0.
          MODIFY ENTITIES OF zi_booking_g4 IN LOCAL MODE
            ENTITY Booking
              UPDATE
                FIELDS ( TravelUuid CurrentStatus TravelId )
                WITH VALUE #(
                              ( %tky         = travel-%tky
                                TravelUuid = travel_data-travel_uuid
                                CurrentStatus = 'Available'
                                TravelId = travel_data-travel_id
                                ) )
          FAILED DATA(failed_travel_data)
          REPORTED DATA(reported_travel_data).
*          MODIFY ENTITIES OF zi_booking_g4 IN LOCAL MODE
*                ENTITY Booking
*                  UPDATE
*                    FIELDS ( TravelUuid TravelId )
*                    WITH VALUE #( ( %tky = travel-%tky
*                                    TravelUuid = travel_data-travel_uuid
*                                    TravelId = travel_data-travel_id
*                                     ) ).
        ELSE.
          DATA attr2 TYPE string.
          DATA attr1 TYPE string VALUE 'WL'.
          DATA cur_status TYPE string.
          attr2 = ( abs( travel_data-empty_seats - 1 ) ).
          CONCATENATE attr1 attr2 INTO cur_status SEPARATED BY space.
          MODIFY ENTITIES OF zi_booking_g4 IN LOCAL MODE
            ENTITY Booking
              UPDATE
                FIELDS ( TravelUuid CurrentStatus TravelId )
                WITH VALUE #(
                              ( %tky         = travel-%tky
                                TravelUuid = travel_data-travel_uuid
                                CurrentStatus = cur_status
                                TravelId = travel_data-travel_id
                                ) ).
          .
        ENDIF.
      ENDIF.
      IF count_rows = 0.

        SELECT SINGLE * FROM zbus_g4
        WHERE bus_id = @travel-BusId
        INTO @DATA(bus_data).

*       Retrieving and updating PNR
        SELECT SINGLE * FROM zvalue
            WHERE row_number = 1
            INTO @DATA(values).

        DATA new_travel_id TYPE int8.
        new_travel_id = values-travel_id + 1.

        UPDATE zvalue SET travel_id = @new_travel_id
        WHERE row_number = 1.

        DATA travel_id TYPE string.
        travel_id = new_travel_id.

*       Creating Travel based on BusId
        MODIFY ENTITIES OF zi_travel_g4
          ENTITY Travel
            CREATE
              SET FIELDS WITH VALUE
                #( ( %cid        = 'MyContentID_1'
                     BusUuid = bus_data-bus_uuid
                     TravelId = new_travel_id
                     BusId = travel-BusId
                     StartDate = travel-StartDate
                     EmptySeats = bus_data-total_seats
                     ) )
        MAPPED DATA(mapped_travel)
        FAILED DATA(failed_travel)
        REPORTED DATA(reported_travel).



*       Reading Travel details based on BusId and Start date
        READ ENTITIES OF zi_travel_g4
        ENTITY Travel
        FIELDS ( TravelId TravelUuid ) WITH VALUE #( FOR created_travel IN mapped_travel-travel
                                                    ( TravelUuid = created_travel-TravelUuid ) )
        RESULT DATA(travel_new_data).

*       Updating Travel Details in Booking
        MODIFY ENTITIES OF zi_booking_g4 IN LOCAL MODE
              ENTITY Booking
                UPDATE
                  FIELDS ( TravelUuid CurrentStatus TravelId )
                  WITH VALUE #( FOR new_data IN travel_new_data
                                ( %tky         = travel-%tky
                                  TravelUuid = new_data-TravelUuid
                                  CurrentStatus = 'Available'
                                  TravelId = new_travel_id
                                  ) ).
      ENDIF.

    ENDLOOP.

  ENDMETHOD.






  METHOD validateAge.

*   Reading Entered Age
    READ ENTITIES OF zi_booking_g4 IN LOCAL MODE
      ENTITY Booking
        FIELDS ( PassangerAge ) WITH CORRESPONDING #( keys )
      RESULT DATA(passangers).

*   Validating Entered Age
    LOOP AT passangers INTO DATA(passanger).

      IF passanger-PassangerAge > 120.

        APPEND VALUE #( %tky = passanger-%tky ) TO failed-Booking.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.







  METHOD changeOnCreate.


*   Code for
*       a) generating PNR on new booking creation (will fail when cancellation occurs)
*       b) updating Current status when booking is created
*       b) associating with Travel

*   Reading BusId and Start Date from Booking
    READ ENTITIES OF zi_booking_g4 IN LOCAL MODE
      ENTITY Booking
        FIELDS ( BusId StartDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    LOOP AT travels INTO DATA(travel).

*     Booking Date
      DATA booking_date TYPE C LENGTH 20.
      booking_date = sy-datum.
*      GET TIME STAMP FIELD booking_date.


      MODIFY ENTITIES OF zi_booking_g4 IN LOCAL MODE
                    ENTITY Booking
                      UPDATE
                        FIELDS ( BookingDate )
                        WITH VALUE #( ( %tky = travel-%tky
                                        BookingDate = booking_date
                                         ) ).

*       Retrieving and updating PNR
      SELECT SINGLE * FROM zvalue
          WHERE row_number = 1
          INTO @DATA(values).

      DATA new_pnr TYPE int8.
      new_pnr = values-pnr + 1.

      UPDATE zvalue SET pnr = @new_pnr
      WHERE row_number = 1.

      DATA pnr TYPE string.
      pnr = new_pnr.


*       Generating required Current Status.
      DATA current_status TYPE string VALUE 'CONFIRMED'.

*      SELECT SINGLE * FROM ztravel_g4
*      WHERE bus_id = @travel-BusId AND start_date = @travel-StartDate
*      INTO @DATA(travel_new_data).

      READ ENTITIES OF zi_travel_g4
      ENTITY Travel
        FIELDS ( EmptySeats StartDate BusId ) WITH VALUE #( ( TravelUuid = travel-TravelUuid ) )
      RESULT DATA(travel_new_datas).

      LOOP AT travel_new_datas INTO DATA(travel_new_data).
        IF travel_new_data-StartDate = travel-StartDate AND travel_new_data-BusId = travel-BusId.
          IF travel_new_data-EmptySeats <= 0.
            DATA attr1 TYPE string VALUE 'WL'.
            DATA attr2 TYPE string.
            attr2 = ( abs( travel_new_data-EmptySeats - 1 ) ).
            current_status = ''.
            CONCATENATE attr1 attr2 INTO current_status SEPARATED BY space.

          ENDIF.
*       UPDATING PNR, Travel Id, Travel UUID and Current Status In Booking
          MODIFY ENTITIES OF zi_booking_g4 IN LOCAL MODE
                    ENTITY Booking
                      UPDATE
                        FIELDS ( Pnr CurrentStatus )
                        WITH VALUE #( ( %tky = travel-%tky
                                        Pnr = pnr
                                        CurrentStatus = current_status
                                         ) ).
*   Code for updating Empty seats when booking is created

          DATA new_empty_seats TYPE int8.
          new_empty_seats = ( travel_new_data-EmptySeats - 1 ).

*    UPDATE ztravel_g4 SET empty_seats = @new_empty_seats
*    WHERE bus_id = @travel-BusId AND start_date = @travel-StartDate.
          MODIFY ENTITIES OF zi_travel_g4
                          ENTITY Travel
                            UPDATE
                              FIELDS ( EmptySeats )
                              WITH VALUE #( ( %tky = travel_new_data-%tky
                                              EmptySeats = new_empty_seats
                                               ) ).
        ENDIF.
      ENDLOOP.

*       UPDATING PNR, Travel Id, Travel UUID and Current Status In Booking
      MODIFY ENTITIES OF zi_booking_g4 IN LOCAL MODE
                ENTITY Booking
                  UPDATE
                    FIELDS ( Pnr CurrentStatus )
                    WITH VALUE #( ( %tky = travel-%tky
                                    Pnr = pnr
                                    CurrentStatus = current_status
                                     ) ).

    ENDLOOP.

  ENDMETHOD.

  METHOD validatePhoneNumber.
    READ ENTITIES OF zi_booking_g4 IN LOCAL MODE
    ENTITY Booking
      FIELDS ( PhoneNumber ) WITH CORRESPONDING #( keys )
    RESULT DATA(bookings_phone)
    FAILED DATA(failed_phone)
    REPORTED DATA(reported_phone).

    LOOP AT bookings_phone INTO DATA(booking_phone).

      DATA len_phone_number TYPE int1.
      len_phone_number = strlen( booking_phone-PhoneNumber ).
      DATA phone_characters_correct TYPE int1.
      IF booking_phone-PhoneNumber CO '1234567890'.
        phone_characters_correct = 1.
      ELSE.
        phone_characters_correct = 0.
      ENDIF.
      IF len_phone_number < 10 OR phone_characters_correct = 0.
        APPEND VALUE #( %tky = booking_phone-%tky ) TO failed-Booking.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD startDate.
    READ ENTITIES OF zi_booking_g4 IN LOCAL MODE
      ENTITY Booking
        FIELDS ( StartDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(bookings_start_date)
      FAILED DATA(failed_start_date)
      REPORTED DATA(reported_start_date).

    LOOP AT bookings_start_date INTO DATA(booking_start_date).
      DATA: cur_date    TYPE d,
            latest_date TYPE d.
      cur_date = sy-datum.
      latest_date = cur_date + 90.
      IF booking_start_date-StartDate < cur_date OR booking_start_date-StartDate > latest_date.
        APPEND VALUE #( %tky = booking_start_date-%tky ) TO failed-Booking.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD onCancellation.
    READ ENTITIES OF zi_booking_g4 IN LOCAL MODE
    ENTITY Booking
      FIELDS ( TravelUuid ) WITH CORRESPONDING #( keys )
    RESULT DATA(bookings_deletion)
    FAILED DATA(failed_booking_deletion)
    REPORTED DATA(reported_booking_deletion).

    LOOP AT bookings_deletion INTO DATA(booking_deletion).

      READ ENTITIES OF zi_travel_g4
      ENTITY Travel
        FIELDS ( EmptySeats ) WITH VALUE #( ( TravelUuid = booking_deletion-TravelUuid ) )
      RESULT DATA(travel_empty_seats)
      FAILED DATA(failed_empty_seats)
      REPORTED DATA(reported_empty_seats).

      MODIFY ENTITIES OF zi_travel_g4
              ENTITY Travel
                UPDATE
                  FIELDS ( EmptySeats )
                  WITH VALUE #( FOR travel_empty_seat IN travel_empty_seats
                                  ( %tky = travel_empty_seat-%tky
                                      EmptySeats = travel_empty_seat-EmptySeats + 1
                                   ) ).
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
