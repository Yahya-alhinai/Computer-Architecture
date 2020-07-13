`timescale 1ns / 1ps

//TODO 
//modify the cache FSM so that it implements 
//an n-way set associative cache
//also implement two replacement strategies
//LRU(least recently used) and MRU(most recently used) 

import cache_def::*; 

/*cache finite state machine*/
module dm_cache_fsm(input  bit clk, input  bit rst,
        input  cpu_req_type  cpu_req,       
        //CPU request input (CPU->cache)
        input  mem_data_type  mem_data,     
        //memory response (memory->cache)
        output mem_req_type   mem_req,      
        //memory request (cache->memory)
        output cpu_result_type cpu_res      
        //cache result (cache->CPU)
    );
  timeunit  1ns;  
  timeprecision  1ps;
  /*write  clock*/
  
  typedef enum {idle, compare_tag, allocate, write_back} cache_state_type;
  /*FSM state register*/
  cache_state_type vstate,rstate;
  
  int way = 0;
  int counter[0:1023][0:N-1];
  int hit;
  
  initial  begin
      for (int i=0; i<1024; i++) 
          begin
              for(int j=0; j < N; j++)
                  counter[i][j] = 0;
          end
    end
  
  /*interface signals to tag memory*/
  cache_tag_type tag_read[0:N-1];                 //tag  read  result
  cache_tag_type tag_write;                //tag  write  data
  cache_req_type tag_req;                  //tag  request
  
  
  /*interface signals to cache data memory*/
  cache_data_type data_read[0:N-1];               //cache  line  read  data
  cache_data_type data_write;              //cache  line  write  data
  cache_req_type data_req;                 //data  req
  cache_data_type data_write_all[0:N-1];
  
  /*temporary variable for cache controller result*/
  cpu_result_type v_cpu_res;  
  cpu_result_type v_cpu_res_all[0:N-1];  
  
  /*temporary variable for memory controller request*/
  mem_req_type v_mem_req;
  mem_req_type v_mem_req_all[0:N-1];
  
  assign mem_req = v_mem_req;              //connect to output ports
  assign cpu_res = v_cpu_res; 

    always_comb begin
        /*-------------------------default values for all signals------------*/
        /*no state change by default*/
        vstate = rstate;                  
        v_cpu_res = '{0, 0, 0}; tag_write = '{0, 0, 0}; 
        
        for(int i=0; i <N; i++)
            begin
            v_cpu_res_all[i] = '{0,0,0};
            end
        
        /*read tag by default*/
        tag_req.we = '0;             
        /*direct map index for tag*/
        tag_req.index = cpu_req.addr[13:4];
        /*need tag for getting the way*/
       // tag_req.tag = cpu_req.addr[31:14];
        
         
        /*read current cache line by default*/
        data_req.we  =  '0;
        /*direct map index for cache data*/
        data_req.index = cpu_req.addr[13:4];
        
        /*modify correct word (32-bit) based on address*/
        data_write_all = data_read;
        
        for(int i=0; i < N; i++)
        begin        
        case(cpu_req.addr[3:2])
        2'b00:data_write_all[i][31:0]  =  cpu_req.data;
        2'b01:data_write_all[i][63:32]  =  cpu_req.data;
        2'b10:data_write_all[i][95:64]  =  cpu_req.data;
        2'b11:data_write_all[i][127:96] = cpu_req.data;
        endcase
        end
        
        /*read out correct word(32-bit) from cache (to CPU)*/
        
        for(int i=0; i <N; i++)
        begin
        case(cpu_req.addr[3:2])
        2'b00:v_cpu_res_all[i].data  =  data_read[i][31:0];
        2'b01:v_cpu_res_all[i].data  =  data_read[i][63:32];
        2'b10:v_cpu_res_all[i].data  =  data_read[i][95:64];
        2'b11:v_cpu_res_all[i].data  =  data_read[i][127:96];
        endcase
        end
        
        /*memory request address (sampled from CPU request)*/
        v_mem_req.addr = cpu_req.addr; 
        
        /*memory request data (used in write)*/
        for(int i=0; i<N; i++)
            begin
            v_mem_req_all[i].data = data_read[i]; 
            end
        
        v_mem_req.rw  = '0; //could BE CHANGED 
        
        
        //if(mem_data.ready)
        //v_mem_req.valid = '0;
        
        //------------------------------------Cache FSM-------------------------
        case(rstate)
        
        
            /*idle state*/
            idle : begin
                /*If there is a CPU request, then compare cache tag*/
                if (cpu_req.valid)
                   vstate = compare_tag;
                end
                
                
            /*compare_tag state*/ 
            compare_tag : begin
              /*cache hit (tag match and cache entry is valid)*/
                    hit = 0;
                    for(int i = 0; i < N; i++) begin
                      if (cpu_req.addr[TAGMSB:TAGLSB] == tag_read[i].tag && tag_read[i].valid) begin
                          way = i;
                          hit = 1;
                          vstate = idle; 
                          counter[tag_req.index][way] += 1;
                          
                          data_write = data_write_all[way];
                          v_cpu_res.data = v_cpu_res_all[way].data;
                          v_mem_req.data = v_mem_req_all[way].data;
                          
                          v_cpu_res.ready = '1;

                          /*write hit*/
                          if (cpu_req.rw) begin 
                          /*read/modify cache line*/
                            tag_req.we = '1; data_req.we = '1;
                          /*no change in tag*/
                            tag_write.tag = tag_read[way].tag; 
                            tag_write.valid = '1;
                          /*cache line is dirty*/
                            tag_write.dirty = '1;           
                            end 
                        end
                    end
              /*xaction is finished*/
              

              
              /*cache miss*/
                if(hit == 0) begin 
                
                automatic int minimumcount = counter[tag_req.index][0];
                automatic int location = 0;
                for (int i = 1; i < N; i++)
                    begin
                        if(counter[tag_req.index][i] < minimumcount)
                            begin
                               minimumcount =  counter[tag_req.index][i];
                               location = i;
                            end
                    end
                way = location;
                counter[tag_req.index][way] = 0;

                /*generate new tag*/
                tag_req.we = '1; 
                tag_write.valid = '1;
                /*new tag*/
                tag_write.tag = cpu_req.addr[TAGMSB:TAGLSB];
                /*cache line is dirty if write*/
                tag_write.dirty = cpu_req.rw;
                /*generate memory request on miss*/
                v_mem_req.valid = '1; 
                
                
                /*compulsory miss or miss with clean block*/
                if (tag_read[way].valid == 1'b0 || tag_read[way].dirty == 1'b0)
                     /*wait till a new block is allocated*/
                     vstate = allocate;
                else begin
                     /*miss with dirty line*/
                        /*write back address*/
                        v_mem_req.addr = {tag_read[way].tag, cpu_req.addr[TAGLSB-1:0]};
                        v_mem_req.rw = '1; 
                        /*wait till write is completed*/
                        vstate = write_back;
                end
              end 
            end
            
            
            /*wait for allocating a new cache line*/
            allocate: begin           
               v_mem_req.valid = '0;   
               /*memory controller has responded*/
               if (mem_data.ready) begin
               /*re-compare tag for write miss (need modify correct word)*/
               vstate = compare_tag; 
               data_write = mem_data.data;
               /*update cache line data*/
               data_req.we = '1; 
               end 
            end
            
            /*wait for writing back dirty cache line*/
            write_back : begin         
               /*write back is completed*/
               if (mem_data.ready) begin
                  /*issue new memory request (allocating a new line)*/
                  v_mem_req.valid = '1;            
                  v_mem_req.rw = '0;           
                  vstate = allocate; 
               end
            end
        endcase
    end //end always_comb
       
    always_ff @(posedge(clk)) begin
        if (rst) 
          rstate <= idle;       //reset to idle state
        else 
          rstate <= vstate;

        //print the queue value
    end //end always_ff
    
    /*connect cache tag/data memory*/
    dm_cache_tag  ctag(.*);
    dm_cache_data cdata(.*);
    
endmodule