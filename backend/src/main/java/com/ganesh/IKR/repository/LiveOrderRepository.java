package com.ganesh.IKR.repository;
import com.ganesh.IKR.entity.LiveOrder;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface LiveOrderRepository extends JpaRepository<LiveOrder, Long> { Optional<LiveOrder> findByUserIdAndIdempotencyKey(Long userId, String idempotencyKey); }
