package com.ganesh.IKR.repository;

import com.ganesh.IKR.entity.Instrument;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import java.util.List;

public interface InstrumentRepository extends JpaRepository<Instrument, Long> {
    @Query("select i from Instrument i where upper(i.tradingsymbol) like upper(concat('%', :query, '%')) "
            + "or upper(coalesce(i.name, '')) like upper(concat('%', :query, '%')) "
            + "order by case when upper(i.tradingsymbol) = upper(:query) then 0 else 1 end, "
            + "case when i.exchange = 'NSE' then 0 else 1 end, i.exchange, i.tradingsymbol")
    List<Instrument> search(String query, org.springframework.data.domain.Pageable pageable);
}
