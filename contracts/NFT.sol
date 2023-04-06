/**
*ERC-1155: Multi Token Standard
*snm ver2
*【このコントラクトの概要】
*１つのコントラクトで、複数のユーザーがNFTを発行できる仕様

*【このコントラクトの仕様】
*ミント、バーン、購入、NFT情報の取得など、一般的な機能を所持
*NFTに有効期限を設定可能
*有効期限は、token id と　所有者に紐づいている
*有効期限付きのNFTを購入しても、NFTの枚数は増えない。期限が更新されるだけ。
*metadataのURIは、creator address 毎に紐づいている
*

*【v1とv2の主な変更点】
*価格の変更が可能
*metadataのURIは、creator address 毎に紐づいている
*有効期限の追加
*有効期限のある同一token idのトークンは、複数所持出来ない
*有効期限のあるトークンは、二次流通出来ない。（open seaなどで売る事が出来ない）
*クリエイターの在庫数は誰でも閲覧可能
*トークン購入時、支払金額と、コントラクトが所持しているtoken costの値と比較する

*/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFT is ERC1155 ,Ownable{

    /**----------------------------------------------
    * initial setting（変数の定義など）
    ------------------------------------------------*/   
    uint256 constant ownerRoyaltyRate = 300;//3%
    
    //NFTの構造体定義
    struct NFTStr{
        uint256 id;
        uint256 issued;//発行数
        uint256 cost;
        uint256 expirationDate;//有効期限
        address creater;
    }

    //mapping(uint256=>bool) exist;//「tokenId => クリエイター」のマッピング
    mapping(uint256=>address) exist;//「tokenId => クリエイター」のマッピング　token idの存在チェック用
    mapping(address=>uint256) balances;//クリエイター毎の残高
    mapping(address=>uint256[]) createTokenId;//クリエイターが発行したtokenID
    mapping(address=>string) baseMetadataURIPrefix;//クリエイター毎のbaseMetadataURI
    mapping(address=>mapping(uint256=>uint256)) tokenExpirationDate;//購入者のアドレス=>(token_id=>tokenの有効期限:timestamp)

    NFTStr[] NFTData;//NFTを保存しておく変数

    //デプロイ時に発行するNFTの設定
    constructor() public ERC1155("") {

    }

    /**----------------------------------------------
    * eventの定義
    ------------------------------------------------*/   
    event Mint(uint256 _id, uint256 _quantity, uint256 _cost , uint256 _expirationDate);
    event BuyToken(uint256 _id, uint256 _quantity, uint256 _cost , uint256 _expirationDate);
    event Burn(uint256 _id, uint256 _quantity);
    event Withdraw(uint256 _amount);
    event SetURI(string _uri);

    /**----------------------------------------------
    * 関数修飾子の定義
    ------------------------------------------------*/   
    //NFTの存在チェック
    modifier existCheck(uint256 _id){
        require(exist[_id] != address(0) ,"The NFT does not exist.");
        _;
    }

    //NFTのクリエイターチェック＝指定のtoken idが、そのクリエイターのものかをチェック
    modifier createrCheck(address _creater ,uint256 _id){
        uint256[] memory _ids = createTokenId[_creater];
        uint _length = _ids.length;
        bool _flg = false;
        for(uint256 _i;_i < _length;_i++){
            if(_ids[_i] == _id){
                _flg = true;
                break;
            }
        }
        require(_flg == true ,"The NFT does not yours.");
        _;
    }

    /**----------------------------------------------
    * コントラクト関数の定義
    ------------------------------------------------*/ 

    /* 一般用の関数 
    ------------------------------------------------*/ 
     //特定のクリエイターのNFTの情報を取得する
    function getNFTList(address _creater) external view returns(NFTStr [] memory){
        NFTStr [] memory _NFTData = NFTData;
        uint256 [] memory _ids = createTokenId[_creater];
        uint256 _id;
        uint256 _length = _ids.length;
        NFTStr[] memory _creatersNFTData = new NFTStr[](_length); 
        for(uint256 _i = 0;_i < _length;_i++){
            _id = _ids[_i];
            _creatersNFTData[_i] = _NFTData[_id];
        }
        return _creatersNFTData;
    }

    //OpenSeaなどが、NFTのメタデータを取得する関数
    function uri(uint256 _id) public view override returns (string memory) {
        address _creater = exist[_id];
        string memory _baseMetadataURIPrefix = baseMetadataURIPrefix[_creater];
        return string(abi.encodePacked(
            _baseMetadataURIPrefix,
            Strings.toString(_id),
            ''
        ));
    }

    //特定のクリエイターの、自分が所持しているNFT情報（token id,所持数,有効期限timestamp）を配列で取得
    function getOwnNFTList(address _creater) external view returns(uint256 [] memory , uint256 [] memory, uint256 [] memory){
        NFTStr [] memory _NFTData = NFTData;
        uint256 [] memory _ids = createTokenId[_creater];
        uint256 _length = _ids.length;
        
        uint256 _balance;
        uint256 _id;
        uint256[] memory _balances = new uint256[](_length); 
        uint256[] memory _tokenExpirationDate = new uint256[](_length);

        for (uint256 _i = 0; _i < _length; _i++){
            _id = _ids[_i];
            _balance = balanceOf(msg.sender,_id);
            _balances[_i] = _balance;//数量
            if(_NFTData[_id].expirationDate == 0){//有効期限がない場合
                _tokenExpirationDate[_i] = 9999999999999;//有効期限 timestamp　単位は秒（ミリ秒で計算するプログラムでは1000倍して使用）
            }else{//有効期限がある場合
                _tokenExpirationDate[_i] = tokenExpirationDate[msg.sender][_id];//有効期限 timestamp
            }
        }

        return (_ids,_balances,_tokenExpirationDate);

    }

    //NTFを購入
    function buyToken(address _creater,uint256 _id,uint256 _quantity) external payable existCheck(_id){
        
        uint256 _balance = balanceOf(_creater,_id);
        uint256 tokenCost = NFTData[_id].cost;
        uint256 _expirationDate = 0;
        uint256 _cost = _quantity * tokenCost;
        require(_cost == msg.value ,"The payment amount is incorrect.");//unicodeを指定する事で、日本語を設定出来る。
        require(_creater != msg.sender ,unicode"受け取りアドレスが不正です。");//unicodeを指定する事で、日本語を設定出来る。
        require(_quantity > 0,unicode"数量は必須入力です。");//unicodeを指定する事で、日本語を設定出来る。
        require(_balance >= _quantity ,"The quantity entered exceeds the stock amount.");//unicodeを指定する事で、日本語を設定出来る。

        //有効期限が無いトークンの場合 
        if(NFTData[_id].expirationDate == 0){
            //トークンを購入者へ送る
            _safeTransferFrom(_creater,msg.sender,_id,_quantity,"");
        }

        //有効期限があるトークンで、まだ未所持の場合
        if(NFTData[_id].expirationDate != 0 && tokenExpirationDate[msg.sender][_id] == 0){
            //何個購入されても"1個だけ"トークンを購入者へ送る
            _safeTransferFrom(_creater,msg.sender,_id,1,"");
        }

        //有効期限があるトークンの場合：有効期限をセット
        if(NFTData[_id].expirationDate != 0){
            _expirationDate = getTokenExpirationDate(_id,_quantity,NFTData[_id].expirationDate);//有効期限をtimestampで取得
            tokenExpirationDate[msg.sender][_id] = _expirationDate;//有効期限の更新
        }

        //コントラクトのオーナーへのロイヤリティを計算
        uint256 _ownerRoyalty = (msg.value / 10000) * 300; 
        uint256 _createrAmount = msg.value - _ownerRoyalty; 

        address _owner = owner();

        //クリエイターとコントラクトオーナーの口座へ入金
        balances[_creater] += _createrAmount;
        balances[_owner] += _ownerRoyalty;

        emit BuyToken(_id, _quantity, _cost, _expirationDate);

    }

    //指定のアドレスが所持している残高
    function getBalance() external view returns(uint256){
        return balances[msg.sender];
    }

    //所持している残高から引き出す
    function withdraw() external{
        require(balances[msg.sender] > 0,unicode"残高がありません。");
        uint256 _amount = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(_amount);//msg.sender アドレスに、任意の_amountを送金する
        //msg.sender.transfer(_amount);//この書き方でもよいかも。
        emit Withdraw(_amount);
    }

    //有効期限のあるNFTの二次流通を禁止
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        
        NFTStr [] memory _NFTData = NFTData;

        for (uint256 i = 0; i < ids.length; i++) {
            uint _id = ids[i];
            address _creater = exist[_id];

            //送信元とクリエイターのアドレスが同じ場合　もしくは、有効期限の内トークンは転送を許可する
            require(from == _creater || _NFTData[_id].expirationDate == 0, "Transfer not allowed");
        }
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    //新たなNTFを発行
    function mint(uint256 _quantity,uint256 _cost,uint256 _expirationDate) external{
        require(_quantity != 0 ,"quantity required.");
        require(_cost != 0 ,"cost required.");
        uint256 _id = NFTData.length;
        _mint(msg.sender, _id, _quantity, "");
        NFTStr memory newNFT = NFTStr(_id,_quantity,_cost,_expirationDate,msg.sender);
        NFTData.push(newNFT);
        exist[_id] = msg.sender;
        createTokenId[msg.sender].push(_id);
        tokenExpirationDate[msg.sender][_id] = 0;//有効期限をセット
        emit Mint(_id, _quantity, _cost, _expirationDate);
    }

    //NTFを燃やす
    function burn(uint256 _id,uint256 _quantity) external existCheck(_id) createrCheck(msg.sender,_id) {
        uint256 _balance = balanceOf(msg.sender,_id);
        require(_quantity != 0,"quantity required.");
        require(_balance >= _quantity,unicode"数量が所持数を超えています。");

        //指定のアドレスが所有している指定のIDのNTFを指定の数量燃やす関数
        _burn(msg.sender, _id, _quantity);
        emit Burn(_id, _quantity);
    }

    //NFTの発行者（クリエイター）がいくつ所有しているか？＝NFTの残数がいくつか？
    function balanceOfCreater(uint256 _id,address creater) external view existCheck(_id) createrCheck(creater ,_id) returns(uint256){
        uint256 _balance = balanceOf(creater,_id);
        return _balance;
    }

    /* NFTの発行者（クリエイター）専用の関数 
    ------------------------------------------------*/ 
    //MetaDataのURIを変更
    function setURI(string memory _uri) external {
        require(keccak256(abi.encodePacked(_uri)) != keccak256(abi.encodePacked("")),unicode"URIが入力されていません。");//unicodeを指定する事で、日本語を設定出来る。
        baseMetadataURIPrefix[msg.sender] = _uri;
        emit SetURI(_uri);
    }

    //任意のtoken idの販売価格を変更
    function updateCost(uint256 _id, uint256 _cost) external existCheck(_id) createrCheck(msg.sender,_id) {
        require(_cost != 0 ,"cost required.");
        NFTData[_id].cost = _cost;
    }

    //任意のtoken idのcostを取得
    function getCost(uint256 _id) external view returns (uint256) {
        return NFTData[_id].cost;
    }

    //関数実行者の任意のtoken idの有効期限を取得
    function getExpirationDate(uint256 _id) external view returns (uint256) {
        uint256 _expirationDate = tokenExpirationDate[msg.sender][_id];//既存の有効期限を取得
        return _expirationDate;
    }


    /* コントラクト内専用の関数 
    ------------------------------------------------*/ 
    //有効期限を取得
    function getTokenExpirationDate(uint256 _id,uint256 _quantity,uint256 _expirationDate) private view returns (uint256) {

        //規準時間の取得：既存のNFTに有効期限が残っていたら、それに加算。残っていなければ、現在の時刻に加算
        uint256 _existing_expirationDate = tokenExpirationDate[msg.sender][_id];//既存の有効期限を取得
        uint256 baseTimestamp = block.timestamp;//現在のtimestamp
        if(_existing_expirationDate > baseTimestamp){
            baseTimestamp = _existing_expirationDate;
        }

        //tokenの購入個数 * 1個当たりの有効期限（日） * 1日を秒数に変換した値
        uint256 addTime = _quantity * _expirationDate * 24 * 60 * 60;//24 * 60 * 60 = 1日を秒数に変換
        uint256 _tokenExpirationDate = 0;
        if(addTime != 0){
            _tokenExpirationDate = baseTimestamp + addTime;
        }
        return _tokenExpirationDate;
    }

    
}