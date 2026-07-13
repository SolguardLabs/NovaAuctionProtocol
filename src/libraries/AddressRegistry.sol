// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library AddressRegistry {
    error AddressAlreadyPresent(address account);
    error AddressMissing(address account);
    error InvalidAddress();

    struct Registry {
        address[] values;
        mapping(address => uint256) indexPlusOne;
    }

    function add(
        Registry storage registry,
        address account
    ) internal returns (bool added) {
        if (account == address(0)) revert InvalidAddress();
        if (contains(registry, account)) revert AddressAlreadyPresent(account);
        registry.values.push(account);
        registry.indexPlusOne[account] = registry.values.length;
        return true;
    }

    function addIfMissing(
        Registry storage registry,
        address account
    ) internal returns (bool added) {
        if (account == address(0)) revert InvalidAddress();
        if (contains(registry, account)) return false;
        registry.values.push(account);
        registry.indexPlusOne[account] = registry.values.length;
        return true;
    }

    function remove(
        Registry storage registry,
        address account
    ) internal returns (bool removed) {
        uint256 index = registry.indexPlusOne[account];
        if (index == 0) revert AddressMissing(account);
        uint256 removeIndex = index - 1;
        uint256 lastIndex = registry.values.length - 1;
        if (removeIndex != lastIndex) {
            address last = registry.values[lastIndex];
            registry.values[removeIndex] = last;
            registry.indexPlusOne[last] = removeIndex + 1;
        }
        registry.values.pop();
        delete registry.indexPlusOne[account];
        return true;
    }

    function removeIfPresent(
        Registry storage registry,
        address account
    ) internal returns (bool removed) {
        if (!contains(registry, account)) return false;
        remove(registry, account);
        return true;
    }

    function contains(
        Registry storage registry,
        address account
    ) internal view returns (bool) {
        return registry.indexPlusOne[account] != 0;
    }

    function length(
        Registry storage registry
    ) internal view returns (uint256) {
        return registry.values.length;
    }

    function at(
        Registry storage registry,
        uint256 index
    ) internal view returns (address) {
        return registry.values[index];
    }

    function list(
        Registry storage registry
    ) internal view returns (address[] memory values) {
        values = new address[](registry.values.length);
        for (uint256 i = 0; i < values.length; i++) {
            values[i] = registry.values[i];
        }
    }

    function slice(
        Registry storage registry,
        uint256 start,
        uint256 count
    ) internal view returns (address[] memory values) {
        uint256 total = registry.values.length;
        if (start >= total) return new address[](0);
        uint256 end = start + count;
        if (end > total) end = total;
        values = new address[](end - start);
        for (uint256 i = start; i < end; i++) {
            values[i - start] = registry.values[i];
        }
    }
}
