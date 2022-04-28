pragma solidity ^0.8.8;


import {AppStorage, Modifiers, ItemType, WearableSet, NUMERIC_TRAITS_NUM, EQUIPPED_WEARABLE_SLOTS, PyranihaCollateralTypeInfo} from "../libraries/LibAppStorage.sol";
import {LibPyraniha, PyranihaInfo} from "../libraries/LibPyraniha.sol";
import {LibCompany, CompanyInfo} from "../libraries/LibCompany.sol";




import {LibStrings} from "../../shared/libraries/LibStrings.sol";
// import "hardhat/console.sol";
import {LibMeta} from "../../shared/libraries/LibMeta.sol";
import {LibERC721Marketplace} from "../libraries/LibERC721Marketplace.sol";
import {LibERC721} from "../../shared/libraries/LibERC721.sol";
import {IERC721TokenReceiver} from "../../shared/interfaces/IERC721TokenReceiver.sol";

import {LibDiamond} from "../../shared/libraries/LibDiamond.sol";

contract AdventureFacet is Modifiers {

  function startBasicAdventure(uint256 _pyraId) external onlyPyranihaOwner(_pyraId){
    Pyraniha storage pyraniha = s.pyranihas[_pyraId];
    s = LibAppStorage.diamondStorage();
    
    address sender = LibMeta.msgSender();
    address owner = pyraniha.owner;
    uint256 lastBasicAdventure = pyraniha.lastBasicAdventure;
    require(
        sender == owner || s.operators[owner][sender] || s.approved[_pyraId] == sender || s.petOperators[owner][sender],
        "PyranihaGameFacet: Not owner of token or approved"
       );
    require(pyraniha.status == LibPyraniha.STATUS_PYRANIHA, 
     "LibPyraniha: Only valid for claimed Pyraniha"
     );

     if (block.timestamp < lastBasicAdventure + 1 hours) {
       return false;
     } else {
       pyraniha.numericHealth[3] -= 5;
       pyraniha.experience += 10;
       pyraniha.lastBasicAdventure = uint40(block.timestamp);
       pyraniha.basicAdventureCount += 1;
       return true;
     }


  }

  function startTreasureAdventure(uint256 _pyraId) external onlyPyranihaOwner(_pyraId){
    Pyraniha storage pyraniha = s.pyranihas[_pyraId];
    s = LibAppStorage.diamondStorage();
    
    address sender = LibMeta.msgSender();
    address owner = pyraniha.owner;
    uint256 lastDailyAdventure = pyraniha.lastDailyAdventure;
    require(
        sender == owner || s.operators[owner][sender] || s.approved[_pyraId] == sender || s.petOperators[owner][sender],
        "PyranihaGameFacet: Not owner of token or approved"
       );
    require(pyraniha.status == LibPyraniha.STATUS_PYRANIHA, 
     "LibPyraniha: Only valid for claimed Pyraniha"
     );

     if (block.timestamp < lastDailyAdventure + 24 hours) {
       return false;
     } else {
       pyraniha.numericHealth[3] -= 5;
       pyraniha.experience += 10;
       pyraniha.lastDailyAdventure = uint40(block.timestamp);
       pyraniha.treasureAdventureCount += 1;
       return true;
     }


  }


  function startSocialAdventure(uint256 _pyraId) external onlyPyranihaOwner(_pyraId){
    Pyraniha storage pyraniha = s.pyranihas[_pyraId];
    s = LibAppStorage.diamondStorage();
    
    address sender = LibMeta.msgSender();
    address owner = pyraniha.owner;
    uint256 lastDailyAdventure = pyraniha.lastDailyAdventure;
    require(
        sender == owner || s.operators[owner][sender] || s.approved[_pyraId] == sender || s.petOperators[owner][sender],
        "PyranihaGameFacet: Not owner of token or approved"
       );
    require(pyraniha.status == LibPyraniha.STATUS_PYRANIHA, 
     "LibPyraniha: Only valid for claimed Pyraniha"
     );

     if (block.timestamp < lastDailyAdventure + 24 hours) {
       return false;
     } else {
       pyraniha.numericHealth[3] -= 5;
       pyraniha.experience += 10;
       pyraniha.lastDailyAdventure = uint40(block.timestamp);
       pyraniha.SocialAdventureCount += 1;
       return true;
     }


  }


  function startOtherAdventure(uint256 _pyraId) external onlyPyranihaOwner(_pyraId){
    Pyraniha storage pyraniha = s.pyranihas[_pyraId];
    s = LibAppStorage.diamondStorage();
    
    address sender = LibMeta.msgSender();
    address owner = pyraniha.owner;
    uint256 lastDailyAdventure = pyraniha.lastDailyAdventure;
    require(
        sender == owner || s.operators[owner][sender] || s.approved[_pyraId] == sender || s.petOperators[owner][sender],
        "PyranihaGameFacet: Not owner of token or approved"
       );
    require(pyraniha.status == LibPyraniha.STATUS_PYRANIHA, 
     "LibPyraniha: Only valid for claimed Pyraniha"
     );

     if (block.timestamp < lastDailyAdventure + 24 hours) {
       return false;
     } else {
       pyraniha.numericHealth[3] -= 5;
       pyraniha.experience += 10;
       pyraniha.lastDailyAdventure = uint40(block.timestamp);
       pyraniha.otherAdventureCount += 1;
       return true;
     }


  }

  // Implement BURN ressources function  
  function startCityAdventure(uint256 _pyraId) external onlyPyranihaOwner(_pyraId){
    Pyraniha storage pyraniha = s.pyranihas[_pyraId];
    s = LibAppStorage.diamondStorage();
    
    address sender = LibMeta.msgSender();
    address owner = pyraniha.owner;
    uint256 lastDailyAdventure = pyraniha.lastDailyAdventure;
    require(
        sender == owner || s.operators[owner][sender] || s.approved[_pyraId] == sender || s.petOperators[owner][sender],
        "PyranihaGameFacet: Not owner of token or approved"
       );
    require(pyraniha.status == LibPyraniha.STATUS_PYRANIHA, 
     "LibPyraniha: Only valid for claimed Pyraniha"
     );

     if (block.timestamp < lastDailyAdventure + 24 hours) {
       return false;
     } else {
       pyraniha.numericHealth[3] -= 5;
       pyraniha.experience += 10;
       pyraniha.lastDailyAdventure = uint40(block.timestamp);
       pyraniha.otherAdventureCount += 1;
       return true;
     }


  }
}