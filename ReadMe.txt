RLQueue
Please clone or fork from github. https://github.com/briandw/RLQueue

RLQueue is a simple operation queue for Mac OS X and iOS. It's similar to NSOperationQueue but with the ability to cancel operations and promote operations in the queue to higher priority*. RLOperation uses blocks in the place of delegate callbacks and as such should be highly configureable. 

Using RLQueue:
To use RLQueue you need to include the RLRequestQueue and RLOperation classes from the RLQueue folder. The RLDownloadOperation class is optional. In the simplest case your code can instantiate the RLRequestQueue singleton with [RLRequestQueue sharedQueue] and add a RLOperation or RLDownloadOperation with the appropriate operation and completion blocks. You will likely want to create a subclass of RLOperation for you specific needs. Please see the FlickerExample project for an example. In order to run the FlickerExample you will need to register your own Flickr key and include it in FlickrKey.h

RLQueue has no dependencies outside of Grand Central Dispatch and Blocks (iOS 4 or Mac OS X 10.6).

Copyright © 2011 Brian D Williams under the MIT License.
http://www.opensource.org/licenses/mit-license.php
Follow me on twitter https://twitter.com/InnovationFail


*Promoting operations isn't implemented yet. It may require re-implementing the heap code. 