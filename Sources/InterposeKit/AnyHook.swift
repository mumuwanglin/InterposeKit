import Foundation


public class AnyHook {
    public let `class`: AnyClass
    public let selector: Selector
    public internal(set) var state = State.prepared
    // fetched at apply time, changes late, thus class requirement
    public internal(set) var origIMP: IMP?
    // else we validate init order
    public internal(set) var replacementIMP: IMP!
    
    /// The possible task states
    public enum State: Equatable {
        /// The task is prepared to be nterposed.
        case prepared
        
        /// The method has been successfully interposed.
        case interposed
        
        /// An error happened while interposing a method.
        case error(Interpose.Error)
    }
    
    init(`class`: AnyClass, selector: Selector) throws {
        self.selector = selector
        self.class = `class`
        // Check if method exists
        try validate()
        // replacementIMP = imp_implementationWithBlock(implementation(self))
    }
    
    func replaceImplementation() throws {
        preconditionFailure("Not implemented")
    }
    
    func resetImplementation() throws {
        preconditionFailure("Not implemented")
    }
    
    
    /// Apply the interpose hook.
    public func apply() throws {
        try execute(newState: .interposed) { try replaceImplementation() }
    }
    
    /// Revert the interpose hoook.
    public func revert() throws {
        try execute(newState: .prepared) { try resetImplementation() }
    }
    
    //    public func callAsFunction<U>(_ type: U.Type) -> U {
    //        unsafeBitCast(origIMP, to: type)
    //    }
    
    /// Validate that the selector exists on the active class.
    @discardableResult func validate(expectedState: State = .prepared) throws -> Method {
        guard let method = class_getInstanceMethod(`class`, selector) else { throw Interpose.Error.methodNotFound }
        guard state == expectedState else { throw Interpose.Error.invalidState }
        return method
    }
    
    private func execute(newState: State, task: () throws -> Void) throws {
        do {
            try task()
            state = newState
        } catch let error as Interpose.Error {
            state = .error(error)
            throw error
        }
    }
    
    /// Release the hook block if possible.
    public func cleanup() {
        switch state {
        case .prepared:
            Interpose.log("Releasing -[\(`class`).\(selector)] IMP: \(replacementIMP!)")
            imp_removeBlock(replacementIMP)
        case .interposed:
            Interpose.log("Keeping -[\(`class`).\(selector)] IMP: \(replacementIMP!)")
        case let .error(error):
            Interpose.log("Leaking -[\(`class`).\(selector)] IMP: \(replacementIMP!) due to error: \(error)")
        }
    }
}

public class TypedHook<MethodSignature, HookSignature>: AnyHook {
    public var original: MethodSignature {
        unsafeBitCast(origIMP, to: MethodSignature.self)
    }
}