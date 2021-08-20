//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-nio- open source project
//
// Copyright (c) 2018-2021 ZeeZide GmbH. and the swift-nio- project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//


extension Command {
    
    /**
     * This initializer creates `Command` values from String command names and
     * string arguments (as parsed by the `MessageParser`).
     *
     * The parser validates the argument counts etc and throws exceptions on
     * unexpected input.
     */
    init(_ command: String, arguments: [ String ]) throws {
      typealias Error = ParserError
      
      func expect(argc: Int) throws {
        guard argc == arguments.count else {
          throw Error.invalidArgumentCount(command: command,
                                           count: arguments.count, expected: argc)
        }
      }
      func expect(min: Int? = nil, max: Int? = nil) throws {
        if let max = max {
          guard arguments.count <= max else {
            throw Error.invalidArgumentCount(command: command,
                                             count: arguments.count,
                                             expected: max)
          }
        }
        if let min = min {
          guard arguments.count >= min else {
            throw Error.invalidArgumentCount(command: command,
                                             count: arguments.count,
                                             expected: min)
          }
        }
      }
      
      func splitChannelsString(_ s: String) throws -> [ ChannelName ] {
        return try arguments[0].split(separator: ",").map {
          guard let n = ChannelName(String($0)) else {
            throw Error.invalidChannelName(String($0))
          }
          return n
        }
      }
      func splitRecipientString(_ s: String) throws -> [ MessageRecipient ] {
        return try arguments[0].split(separator: ",").map {
          guard let n = MessageRecipient(String($0)) else {
            throw Error.invalidMessageTarget(String($0))
          }
          return n
        }
      }

      switch command.uppercased() {
        case "QUIT": try expect(max:  1); self = .QUIT(arguments.first)
        case "DMID":
          try expect(argc: 1)
          guard let dmid = DMIdentifier(arguments[0]) else {
            throw Error.invalidDMID(arguments[0])
          }
          self = .DMID(dmid)
        
        case "MODE":
          try expect(min: 1)
          guard let recipient = MessageRecipient(arguments[0]) else {
            throw Error.invalidMessageTarget(arguments[0])
          }
          
          switch recipient {
            case .all:
              throw Error.invalidMessageTarget(arguments[0])
            
            case .dm(let dm):
              if arguments.count > 1 {
                var add    = UserMode()
                var remove = UserMode()
                for arg in arguments.dropFirst() {
                  var isAdd = true
                  for c in arg {
                    if      c == "+" { isAdd = true  }
                    else if c == "-" { isAdd = false }
                    else if let mode = UserMode(String(c)) {
                      if isAdd { add   .insert(mode) }
                      else     { remove.insert(mode) }
                    }
                    else {
                      // else: warn? throw?
                      print("Parser: unexpected  mode: \(c) \(arg)")
                    }
                  }
                }
                self = .MODE(dm, add: add, remove: remove)
              }
              else {
                self = .MODEGET(dm)
              }
            
            case .channel(let channelName):
              if arguments.count > 1 {
                var add    = ChannelMode()
                var remove = ChannelMode()
                for arg in arguments.dropFirst() {
                  var isAdd = true
                  for c in arg {
                    if      c == "+" { isAdd = true  }
                    else if c == "-" { isAdd = false }
                    else if let mode = ChannelMode(String(c)) {
                      if isAdd { add   .insert(mode) }
                      else     { remove.insert(mode) }
                    }
                    else {
                      // else: warn? throw?
                      print("Parser: unexpected  mode: \(c) \(arg)")
                    }
                  }
                }
                if add == ChannelMode.banMask && remove.isEmpty {
                  self = .CHANNELMODE_GET_BANMASK(channelName)
                }
                else {
                  self = .CHANNELMODE(channelName, add: add, remove: remove)
                }
              }
              else {
                self = .CHANNELMODE_GET(channelName)
              }
          }

        case "USER":
          // RFC 1459 <username> <hostname> <servername> <realname>
          // RFC 2812 <username> <mode>     <unused>     <realname>
          try expect(argc: 4)
          if let mask = UInt16(arguments[1]) {
            self = .USER(UserInfo(username : arguments[0],
                                     usermask : UserMode(rawValue: mask),
                                     realname : arguments[3]))
          }
          else {
            self = .USER(UserInfo(username   : arguments[0],
                                     hostname   : arguments[1],
                                     servername : arguments[2],
                                     realname   : arguments[3]))
          }
        
        
        case "JOIN":
          try expect(min: 1, max: 2)
          if arguments[0] == "0" {
            self = .UNSUBALL
          }
          else {
            let channels = try splitChannelsString(arguments[0])
            let keys = arguments.count > 1
                     ? arguments[1].split(separator: ",").map(String.init)
                     : nil
            self = .JOIN(channels: channels, keys: keys)
          }
        
        case "PART":
          try expect(min: 1, max: 2)
          let channels = try splitChannelsString(arguments[0])
          self = .PART(channels: channels,
                       message: arguments.count > 1 ? arguments[1] : nil)
        
        case "LIST":
          try expect(max: 2)
          
          let channels = arguments.count > 0
                       ? try splitChannelsString(arguments[0]) : nil
          let target   = arguments.count > 1 ? arguments[1] : nil
          self = .LIST(channels: channels, target: target)
        
        case "ISON":
          try expect(min: 1)
          var dmids = [ DMIdentifier ]()
          for arg in arguments {
            dmids += try arg.split(separator: " ").map(String.init).map {
              guard let dmid = DMIdentifier($0) else {
                throw Error.invalidDMID($0)
              }
              return dmid
            }
          }
          self = .ISON(dmids)
        
        case "PRIVMSG":
          try expect(argc: 2)
          let targets = try splitRecipientString(arguments[0])
          self = .PRIVMSG(targets, arguments[1])
        
        case "NOTICE":
          try expect(argc: 2)
          let targets = try splitRecipientString(arguments[0])
          self = .NOTICE(targets, arguments[1])
        
        case "CAP":
          try expect(min: 1, max: 2)
          guard let subcmd = CAPSubCommand(rawValue: arguments[0]) else {
            throw ParserError.invalidCAPCommand(arguments[0])
          }
          let capIDs = arguments.count > 1
                     ? arguments[1].components(separatedBy: " ")
                     : []
          self = .CAP(subcmd, capIDs)
        
        case "WHOIS":
          try expect(min: 1, max: 2)
          let maskArg = arguments.count == 1 ? arguments[0] : arguments[1]
          let masks   = maskArg.split(separator: ",").map(String.init)
          self = .WHOIS(server: arguments.count == 1 ? nil : arguments[0],
                        usermasks: Array(masks))
        
        case "WHO":
          try expect(max: 2)
          switch arguments.count {
            case 0: self = .WHO(usermask: nil, onlyOperators: false)
            case 1: self = .WHO(usermask: arguments[0], onlyOperators: false)
            case 2: self = .WHO(usermask: arguments[0],
                                onlyOperators: arguments[1] == "o")
            default: fatalError("unexpected argument count \(arguments.count)")
          }

        default:
          self = .otherCommand(command.uppercased(), arguments)
      }
    }
    
    /**
     * This initializer creates `Command` values from numeric commands and
     * string arguments (as parsed by the `MessageParser`).
     *
     * The parser validates the argument counts etc and throws exceptions on
     * unexpected input.
     */
    @inlinable
    init(_ v: Int, arguments: [ String ]) throws {
      if let code = CommandCode(rawValue: v) {
        self = .numeric(code, arguments)
      }
      else {
        self = .otherNumeric(v, arguments)
      }
    }

    /**
     * This initializer creates `Command` values from String command names and
     * string arguments (as parsed by the `MessageParser`).
     *
     * The parser validates the argument counts etc and throws exceptions on
     * unexpected input.
     */
    @inlinable
    init(_ s: String, _ arguments: String...) throws {
      try self.init(s, arguments: arguments)
    }
    
    /**
     * This initializer creates `Command` values from numeric commands and
     * string arguments (as parsed by the `MessageParser`).
     *
     * The parser validates the argument counts etc and throws exceptions on
     * unexpected input.
     */
    @inlinable
    init(_ v: Int, _ arguments: String...) throws {
      try self.init(v, arguments: arguments)
    }
  }



