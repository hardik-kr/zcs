@EndUserText.label: 'Bus Detail Data Projection'
@AccessControl.authorizationCheck: #CHECK
@Search.searchable: true
@Metadata.allowExtensions: true
define root view entity ZC_Bus_g4 as projection on ZI_BUS_G4 as Bus{
    key BusUuid,
    @EndUserText.label: 'Bus ID'
    @Consumption.valueHelpDefinition: [{ entity: {name : 'ZI_BUS_G4', element: 'BusId'}}]
    @Search.defaultSearchElement: true
    BusId,
    @EndUserText.label: 'Bus Name'
    @Consumption.valueHelpDefinition: [{ entity: {name : 'ZI_BUS_G4', element: 'BusName'}}]
    @Search.defaultSearchElement: true
    BusName,
    @EndUserText.label: 'Source'
    @Consumption.valueHelpDefinition: [{ entity: {name : 'ZI_BUS_G4', element: 'Source'}}]
    @Search.defaultSearchElement: true
    Source,
    @EndUserText.label: 'Destination'
    @Consumption.valueHelpDefinition: [{ entity: {name : 'ZI_BUS_G4', element: 'Destination'}}]
    @Search.defaultSearchElement: true
    Destination,
    @EndUserText.label: 'Fare'
    Fare,
    @EndUserText.label: 'Total Seats'
    TotalSeats,
    @EndUserText.label: 'DepartureTime'
    DepartureTime,
    @EndUserText.label: 'Total Duration (in hrs)'
    Duration,
    LastChangedAt,
    LocalLastChangedAt
    
}
