//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-nio-noOutsideClients open source project
//
// Copyright (c) 2018-2021 ZeeZide GmbH. and the swift-nio-noOutsideClients project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIOIRC project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/**
 * Dispatches incoming IRCMessage's to protocol methods.
 *
 * This has a main entry point `irc_msgSend` which takes an `IRCMessage` and
 * then calls the respective protocol functions matching the command of the
 * message.
 *
 * If a dispatcher doesn't implement a method, the
 * `IRCDispatcherError.doesNotRespondTo`
 * error is thrown.
 *
 * Note: Implementors *can* re-implement `irc_msgSend` and still access the
 *       default implementation by calling `irc_defaultMsgSend`. Which contains
 *       the actual dispatcher implementation.
 */
internal protocol Dispatcher {
  // TODO: Improve this, I don't like anything about this except the dispatcher
  //       name :->
  
  // MARK: - Dispatching Function
  func irc_msgSend(_ message: Message) throws
  
  // MARK: - Implementations
  
 
//  func doCAP       (_ cmd      : Command.CAPSubCommand,
//                    _ capIDs   : [ String ])         throws
//
//  func doDMID      (_ dmid     : DMIdentifier)        throws
//  func doUserInfo  (_ info     : UserInfo)        throws
//  func doModeGet   (dmid       : DMIdentifier)        throws
//  func doModeGet   (channel    : ChannelName)     throws
//  func doMode      (dmid       : DMIdentifier,
//                    add        : UserMode,
//                    remove     : UserMode)        throws
//
//  func doWhoIs     (server     : String?,
//                    usermasks  : [ String ])         throws
//  func doWho       (mask       : String?, operatorsOnly opOnly: Bool) throws
//
//  func doJoin      (_ channels : [ ChannelName ]) throws
//  func doPart      (_ channels : [ ChannelName ],
//                    message    : String?)            throws
//  func doPartAll   ()                                throws
//  func doGetBanMask(_ channel  : ChannelName)     throws
//
//  func doNotice    (recipients : [ MessageRecipient ],
//                    message    : String) throws
  func dispatchMessage   (sender     : UserID?,
                    recipients : [ MessageRecipient ],
                    message    : String) throws

//  func doIsOnline  (_ dmids    : [ DMIdentifier ]) throws
//  func doList      (_ channels : [ ChannelName ]?,
//                    _ target   : String?)         throws
//  
//  func doQuit      (_ message  : String?) throws
}

internal enum DispatcherError : Swift.Error {
  
  case doesNotRespondTo(Message)
  
  case identityInUse(DMIdentifier)
  case noSuchIdentifier   (DMIdentifier)
  case noSuchChannel(ChannelName)
  case alreadyRegistered
  case notRegistered
  case cantChangeModeForOtherUsers
}

internal extension Dispatcher {

//  @inlinable
  func irc_msgSend(_ message: Message) throws {
    try irc_defaultMsgSend(message)
  }

  func irc_defaultMsgSend(_ message: Message) throws {
    do {
      switch message.command {
        case .PRIVMSG(let recipients, let payload):
          let sender = message.origin != nil
                     ? UserID(message.origin!) : nil
          try doMessage(sender: sender,
                        recipients: recipients, message: payload)
        case .NOTICE(let recipients, let message):
          try doNotice(recipients: recipients, message: message)
        
        case .DMID   (let dmid):               try doDmid    (dmid)
        case .USER   (let info):               try doUserInfo(info)
        case .ISON   (let dmids):              try doIsOnline(dmids)
        case .MODEGET(let dmIdentity):         try doModeGet (dmid: dmIdentity)
        case .CAP    (let subcmd, let capIDs): try doCAP     (subcmd, capIDs)
        case .QUIT   (let message):            try doQuit    (message)
        
        case .CHANNELMODE_GET(let channelName):
          try doModeGet(channel: channelName)
        case .CHANNELMODE_GET_BANMASK(let channelName):
          try doGetBanMask(channelName)
        
        case .MODE(let dmid, let add, let remove):
          try doMode(dmid: dmid, add: add, remove: remove)
        
        case .WHOIS(let server, let masks):
          try doWhoIs(server: server, usermasks: masks)
        
        case .WHO(let mask, let opOnly):
          try doWho(mask: mask, operatorsOnly: opOnly)
        
        case .JOIN(let channels, _): try doJoin(channels)
        case .UNSUBALL:                 try doPartAll()
        
        case .PART(let channels, let message):
          try doPart(channels, message: message)
        
        case .LIST(let channels, let target):
          try doList(channels, target)
        
        default:
          throw DispatcherError.doesNotRespondTo(message)
      }
    }
    catch let error as InternalDispatchError {
      switch error {
        case .notImplemented:
          throw DispatcherError.doesNotRespondTo(message)
      }
    }
    catch {
      throw error
    }
  }
}

fileprivate enum InternalDispatchError : Swift.Error {
  case notImplemented(function: String)
}

internal extension Dispatcher {
  
  func doPing(_ server: String, server2: String?) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
  func doCAP(_ cmd: Command.CAPSubCommand, _ capIDs: [ String ]) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }

  func doDmid(_ dmid: DMIdentifier) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
  func doUserInfo(_ info: UserInfo) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
  func doModeGet(dmid: DMIdentifier) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
  func doModeGet(channel: ChannelName) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
  func doMode(dmid: DMIdentifier, add: UserMode, remove: UserMode) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }

  func doWhoIs(server: String?, usermasks: [ String ]) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
  func doWho(mask: String?, operatorsOnly opOnly: Bool) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }

  func doJoin(_ channels: [ ChannelName ]) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
  func doPart(_ channels: [ ChannelName ], message: String?) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
  func doPartAll() throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
  func doGetBanMask(_ channel: ChannelName) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }

  func doNotice(recipients: [ MessageRecipient ], message: String) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
  func doMessage(sender: UserID?, recipients: [ MessageRecipient ],
                 message: String) throws
  {
    throw InternalDispatchError.notImplemented(function: #function)
  }

  func doIsOnline(_ dmid: [ DMIdentifier ]) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
  func doList(_ channels : [ ChannelName ]?, _ target: String?) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }

  func doQuit(_ message: String?) throws {
    throw InternalDispatchError.notImplemented(function: #function)
  }
}

