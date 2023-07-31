# CountDataFetch

## Overview  
This project began as a simple app demonstrating how to get a count of documents from the Big Peer 
via the (currently undocumented) `count` HTTP API. The use case in this example was to delay 
displaying a list of documents until we have confirmed, via the count API request, that we have the 
same number of documents in the local store as in the Big Peer, for a given collection. This is 
demonstrated by having a "Syncing..." blocking view overlay on the documents list at start until all 
documents have been synced.    

An addtional requirement was subsequently added, where all attachment data from all queried documents 
must be fetched at launch. This was to satisfy a use case where all document data and attached file 
data needed to be synced before going offline. This demo now also shows an approach to fetching all 
attachment data for each query sync to ensure all data for a given collection is local, at launch 
and subsequently.  

Note that fetches for previously synced attachment data is local and therefore very fast, however a 
first-time download of many documents with attachments data will be slow in proportion to the amount 
of attachment data and the speed of the internet connection. Also note, that this demo focuses on 
this bulk attachment data sync and does not implement the use or display of any of the attachment 
data itself.  

Addtionally, if the HTTP `count` fetch fails, the count of documents on the list view will be zero 
and an empty list will be displayed, even though the sync and attachments fetching succeeded.      

##N.B.  
This demo assumes greater than zero documents exist in the collection at app launch, otherwise the
placeholder "Syncing..." view will not dismiss. Also note that over a WiFi connection a sync of
lightweight documents will be very fast, so to effectively see the described use case in this demo
ensure there are enough documents to take at least several seconds, for example 1K documents with 
some attachments.  

## Setup and Run    
1. Clone this repo to a location on your machine, and open in Xcode.    
2. Navigate to the project `Signing & Capabilities` tab and modify the `Team and Bundle Identifier` 
settings to your Apple developer account credentials to provision building to your device.    
3. In your [Ditto portal](https://portal.ditto.live), create an app to generate an App ID and 
playground token.  
4. Generate an HTTP API KEY  
5. In Terminal, run `cp .env.template .env` at the Xcode project root directory.     
6. Edit `.env` to add environment variables from the portal as in the following example:     
```DITTO_APP_ID=a01b2c34-5d6e-7fgh-ijkl-8mno9p0q12r3```  
```DITTO_PLAYGROUND_TOKEN=a01b2c34-5d6e-7fgh-ijkl-8mno9p0q12r3```      
```DITTO_API_KEY=a01b2c34-5d6e-7fgh-ijkl-8mno9p0q12r3```   
```DITTO_COLLECTION=my_attachments_collection_name```  
7. Clean (**Command + Shift + K**), then build (**Command + B**). This will generate `Env.swift`.    
   (repeat #6 if necessary)

