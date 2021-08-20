import Foundation

enum Command {

    case DMID(DMIdentifier)
    case USER(UserInfo)
    case ISON( [DMIdentifier] )
    case QUIT(String?)
    case JOIN(channels: [ ChannelName ], keys: [ String ]?)
    case UNSUBALL
    case PART(channels: [ ChannelName ], message: String?)
    case LIST(channels: [ ChannelName ]?, target: String?)
    case PRIVMSG([MessageRecipient], String)
    case NOTICE([MessageRecipient], String)
    case MODE(DMIdentifier, add: UserMode, remove: UserMode)
    case MODEGET(DMIdentifier)
    case CHANNELMODE(ChannelName, add: ChannelMode, remove: ChannelMode)
    case CHANNELMODE_GET(ChannelName)
    case CHANNELMODE_GET_BANMASK(ChannelName)
    case WHOIS(server: String?, usermasks: [ String ])
    case WHO(usermask: String?, onlyOperators: Bool)
    case numeric(CommandCode, [ String ])
    case otherCommand(String, [ String ])
    case otherNumeric(Int,    [ String ])

    //MARK: = IRCv3.net

    enum CAPSubCommand: String {
        case LS, LIST, REQ, ACK, NAK, END

        @inlinable
        public var commandAsString: String { return rawValue }
    }
    case CAP(CAPSubCommand, [ String ])
}

extension Command: CustomStringConvertible {

    @inlinable
    var commandAsString: String {
        switch self {
        case .DMID:         return "DMID"
        case .USER:         return "USER"
        case .ISON:         return "ISON"
        case .QUIT:         return "QUIT"
        case .JOIN, .UNSUBALL:         return "JOIN"
        case .PART:           return "PART"
        case .LIST:           return "LIST"
        case .PRIVMSG:        return "PRIVMSG"
        case .NOTICE:         return "NOTICE"
        case .CAP:            return "CAP"
        case .MODE, .MODEGET: return "MODE"
        case .WHOIS:          return "WHOIS"
        case .WHO:            return "WHO"
        case .CHANNELMODE:    return "MODE"
        case .CHANNELMODE_GET, .CHANNELMODE_GET_BANMASK: return "MODE"

        case .otherCommand(let cmd, _): return cmd
        case .otherNumeric(let cmd, _):
            let s = String(cmd)
            if s.count >= 3 { return s }
            return String(repeating: "0", count: 3 - s.count) + s
        case .numeric(let cmd, _):
            let s = String(cmd.rawValue)
            if s.count >= 3 { return s }
            return String(repeating: "0", count: 3 - s.count) + s
        }
    }

    @inlinable
    var arguments: [ String ] {
        switch self {
        case .DMID(let dmID): return [ dmID.stringValue ]
        case .USER(let info):
            if let usermask = info.usermask {
                return [info.username, usermask.stringValue, "*", info.realname ]
            } else {
                return [ info.username,
                         info.hostname ?? info.usermask?.stringValue ?? "*",
                         info.servername ?? "*",
                         info.realname ]
            }
        case .ISON(let dmIDS): return dmIDS.map { $0.stringValue }
        case .QUIT(.none):                       return []
        case .QUIT(.some(let message)):          return [ message ]
        case .JOIN(let channels, .none):         return [ channels.map { $0.stringValue }.joined(separator: ",") ]
        case .JOIN(let channels, .some(let keys)):
            return [ channels.map { $0.stringValue }.joined(separator: ","), keys.joined(separator: ",") ]
        case .UNSUBALL: return [ "0" ]
        case .PART(let channels, .none):
            return [ channels.map { $0.stringValue }.joined(separator: ",") ]
        case .PART(let channels, .some(let m)):
            return [ channels.map { $0.stringValue }.joined(separator: ","), m ]
        case .LIST(let channels, .none):
            guard let channels = channels else { return [] }
            return [ channels.map { $0.stringValue }.joined(separator: ",") ]
        case .LIST(let channels, .some(let target)):
            return [ (channels ?? []).map { $0.stringValue }.joined(separator: ","), target]
        case .PRIVMSG(let recipients, let m), .NOTICE(let recipients, let m):
            return [ recipients.map { $0.stringValue }.joined(separator: ","), m ]
        case .MODE(let name, let add, let remove):
            if add.isEmpty && remove.isEmpty {
                return [ name.stringValue, ""]
            } else if !remove.isEmpty {
                return [ name.stringValue, "-" + remove.stringValue]
            } else {
                return [ name.stringValue, "+" + remove.stringValue]
            }

        case .CHANNELMODE(let name, let add, let remove):
            if add.isEmpty && remove.isEmpty { return [ name.stringValue, "" ]
            } else if !add.isEmpty && !remove.isEmpty {
                return [ name.stringValue, "+" + add.stringValue, "-" + remove.stringValue ]
            } else if !remove.isEmpty {
                return [ name.stringValue, "-" + remove.stringValue ]
            } else {
                return [ name.stringValue, "+" + add.stringValue ]
            }
        case .MODEGET(let name): return [ name.stringValue ]
        case .CHANNELMODE_GET(let name), .CHANNELMODE_GET_BANMASK(let name):
            return [ name.stringValue ]
        case .WHOIS(.some(let server), usermasks: let usermasks):
            return [ server, usermasks.joined(separator: ",") ]
        case .WHOIS(.none, usermasks: let usermasks):
            return [ usermasks.joined(separator: ",") ]
        case .WHO(.none, _):                        return []
        case .WHO(.some(let usermask), false):      return [ usermask ]
        case .WHO(.some(let usermask), true):       return [ usermask, "o" ]
        case .numeric(_, let args),
             .otherCommand(_, let args),
             .otherNumeric(_, let args): return args
        default:
            fatalError("unexpected case \(self)")
        }
    }

    @inlinable
    var description: String {
        switch self {
        case .QUIT(.some(let v)): return "QUIT '\(v)"
        case .QUIT(.none): return "QUIT"
        case .DMID(let v): return "DMID \(v)"
        case .USER(let v): return "USER \(v)"
        case .ISON(let v):
            let dmIDS = v.map { $0.stringValue }
            return "ISON \(dmIDS.joined(separator: ","))"
        case .MODEGET(let dmID):
            return "MODE \(dmID)"
        case .MODE(let dmID, let add, let remove):
            var s = "MODE \(dmID)"
            if !add.isEmpty { s += " +\(add.stringValue)" }
            if !remove.isEmpty { s += " -\(remove.stringValue)" }
            return s
        case .CHANNELMODE_GET(let v):         return "MODE \(v)"
        case .CHANNELMODE_GET_BANMASK(let v): return "MODE b \(v)"
        case .CHANNELMODE(let dmID, let add, let remove):
            var s = "MODE \(dmID)"
            if !add.isEmpty { s += " +\(add.stringValue)" }
            if !remove.isEmpty { s += " -\(remove.stringValue)" }
            return s
        case .UNSUBALL: return "UNSUBSCRIBE ALL"
        case .JOIN(let channels, .none):
            let names = channels.map { $0.stringValue }
            return "JOIN \(names.joined(separator: ","))"
        case .JOIN(let channels, .some(let keys)):
            let names = channels.map { $0.stringValue }
            return "JOIN \(names.joined(separator: ","))" + "keys: \(keys.joined(separator: ","))"
        case .PART(let channels, .none):
            let names = channels.map { $0.stringValue }
            return "PART \(names.joined(separator: ","))"
        case .PART(let channels, .some(let message)):
            let names = channels.map { $0.stringValue }
            return "PART \(names.joined(separator: ",")) '\(message)'"
        case .LIST(.none, .none):             return "LIST *"
        case .LIST(.none, .some(let target)):  return "LIST * @\(target)"
        case .LIST(.some(let channels), .none):
          let names = channels.map { $0.stringValue}
          return "LIST \(names.joined(separator: ",") )"
        case .LIST(.some(let channels), .some(let target)):
            let names = channels.map { $0.stringValue }
            return "LIST @\(target) \(names.joined(separator: ","))"
        case .PRIVMSG(let recipient, let message):
            let to = recipient.map { $0.description }
            return "PRIVMSG \(to.joined(separator: ",")) '\(message)'"
        case .NOTICE (let recipients, let message):
          let to = recipients.map { $0.description }
          return "NOTICE \(to.joined(separator: ",")) '\(message)'"
        case .CAP(let subcmd, let capIDs):
            return "CAP \(subcmd) \(capIDs.joined(separator: ","))"
        case .WHOIS(.none, let masks):
            return "WHOIS \(masks.joined(separator: ","))"
        case .WHOIS(.some(let target), let masks):
            return "WHOIS @\(target) \(masks.joined(separator: ","))"
        case .WHO(.none, _):
            return "WHO"
        case .WHO(.some(let mask), let opOnly):
            return "WHO \(mask)\(opOnly ? " o" : "")"
        case .otherCommand(let cmd, let args):
            return "<Cmd: \(cmd) arg=\(args.joined(separator: ","))>"
        case .otherNumeric(let cmd, let args):
            return "<Cmd: \(cmd) arg=\(args.joined(separator: ","))>"
        case .numeric(let cmd, let args):
            return "<Cmd: \(cmd.rawValue) args=\(args.joined(separator: ","))>"

        }
    }

}
