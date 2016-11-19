//
//  ViewController.swift
//  CoreBT-peripheral
//
//  Created by Yingbo Wang on 11/18/16.
//  Copyright © 2016 Yingbo Wang. All rights reserved.
//

import UIKit
import CoreBluetooth

let TRANSFER_SERVICE_UUID = "BED00F53-489D-4DED-A907-8DEA6601B6B8"
let TRANSFER_CHARACTERISTIC_UUID = "24960871-6C22-454D-BD62-94DD70B6E318"
//let NOTIFY_MTU = 20

let transferServiceUUID = CBUUID(string: TRANSFER_SERVICE_UUID)
let transferCharacteristicUUID = CBUUID(string: TRANSFER_CHARACTERISTIC_UUID)

class ViewController: UIViewController, CBPeripheralManagerDelegate {

    var peripheralManager: CBPeripheralManager?
    var transferCharacteristic: CBMutableCharacteristic?
    
    // the string we want to send to BLE central
    let sendingString = "Hello Bluetooth!"
    
    var dataToSend: Data?
    var sendDataIndex: Int?
    
    @IBAction func buttonClicked(sender: AnyObject) {
        
        print("peripheralManager.startAdvertising().")
        peripheralManager!.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey : [transferServiceUUID]
            ])
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        
        //while (peripheralManager!.state != .poweredOn) { }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()

    }

    func sendEOM() {
        
        let didSend = peripheralManager?.updateValue(
            "EOM".data(using: String.Encoding.utf8)!,
            for: transferCharacteristic!,
            onSubscribedCentrals: nil
        )
        
        if (didSend!) {
            print("Sent: EOM")
        }
        
        // If it didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
        return
        
    }
    
    func sendData() {
        
        print("sendData() invoked.")
        
        guard sendDataIndex! < (dataToSend?.count)! else {
            // No data left.  Do nothing
            return
        }
        
        var didSend = true
        while didSend {
        
            var amountToSend = dataToSend!.count - sendDataIndex!;
            
            /*
            // limit the largest number of bytes per write
            if (amountToSend > NOTIFY_MTU) {
                amountToSend = NOTIFY_MTU;
            }
            */
            
            let bytes_temp1 = ((dataToSend! as NSData).bytes).advanced(by: sendDataIndex!)
            let chunk = Data(
                bytes: bytes_temp1,
                count: amountToSend
            )
            
            didSend = peripheralManager!.updateValue(
                chunk,
                for: transferCharacteristic!,
                onSubscribedCentrals: nil
            )

            if (!didSend) {
                return
            }
            
            sendDataIndex! += amountToSend;
            
            // generate output for data sent in this round
            let stringFromData = NSString(
                data: chunk,
                encoding: String.Encoding.utf8.rawValue
            )
            print("Sent: \(stringFromData)")
            
            // Was it the last data?
            if (sendDataIndex! >= dataToSend!.count) {
                sendEOM()
                return
            }
        }

    }
    // MARK: CBPeripheralManagerDelegate
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
        // case poweredOn = 5
        //print(peripheral.state.rawValue)
        if (peripheral.state != .poweredOn) {
            return
        }
        print("self.peripheralManager powered on.")
        
        transferCharacteristic = CBMutableCharacteristic(
            type: transferCharacteristicUUID,
            properties: CBCharacteristicProperties.notify,
            value: nil,
            permissions: CBAttributePermissions.readable
        )
        
        let transferService = CBMutableService(
            type: transferServiceUUID,
            primary: true
        )
        
        // Add the characteristic to the service
        transferService.characteristics = [transferCharacteristic!]
        
        // And add it to the peripheral manager
        peripheralManager!.add(transferService)

    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        
        print("Central subscribed to characteristic")
        
        dataToSend = sendingString.data(using: String.Encoding.utf8)
        sendDataIndex = 0;
        sendData()
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic")
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // Start sending again
        print("peripheralManagerIsReady(toUpdateSubscribers).")
        sendData()
    }
    
}

